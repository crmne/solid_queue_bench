require "json"
require "rbconfig"
require "fileutils"
require "socket"
require "etc"
require "tmpdir"

require "bench/async_job/redis_service"

module Bench
  class Runner
    SAMPLE_INTERVAL = 0.1
    PROCESS_READY_TIMEOUT = 30
    PROCESS_STOP_TIMEOUT = 5

    def initialize(options)
      @options = options
    end

    def compare
      results = options.fetch(:modes).map { |mode| run_mode(mode) }
      output = {
        generated_at: Time.current.iso8601,
        ruby_version: RUBY_VERSION,
        isolation_level: ActiveSupport::IsolatedExecutionState.isolation_level,
        modes: results
      }

      FileUtils.mkdir_p(options.fetch(:output_dir))
      File.write(output_path, JSON.pretty_generate(output))

      puts JSON.pretty_generate(output)
      output
    end

    def run_single(mode)
      run_mode(mode)
    end

    private

    attr_reader :options

    def run_mode(mode)
      validate_backend_mode!(mode)
      ensure_database_ready!
      stop_registered_processes
      ensure_backend_dependencies!
      cleanup_benchmark_tables
      support_server_pid = start_support_server_if_needed
      set_active_job_queue_adapter!

      run = BenchmarkRun.create!(
        name: options.fetch(:name),
        backend: options.fetch(:backend, "solid_queue"),
        execution_mode: mode,
        workload: options.fetch(:workload),
        capacity: options.fetch(:capacity),
        processes: options.fetch(:processes),
        jobs_count: options.fetch(:jobs),
        payload: options.fetch(:payload)
      )

      supervisor_pids = start_backend_processes(mode)
      wait_for_benchmark_processes!(supervisor_pids)

      sampler = start_resource_sampler(supervisor_pids)
      run.update!(started_at: Time.current)
      enqueue_jobs(run)
      run.update!(enqueued_at: Time.current)
      wait_until_complete(run)
      stop_resource_sampler(sampler)

      summary = summarize(run, sampler)
      run.update!(
        completed_at: summary[:benchmark_finished_at] || Time.current,
        wall_time_s: summary[:wall_time_s],
        jobs_per_second: summary[:jobs_per_second],
        peak_rss_kb: summary[:peak_rss_kb],
        avg_rss_kb: summary[:avg_rss_kb],
        avg_cpu_pct: summary[:avg_cpu_pct],
        peak_cpu_pct: summary[:peak_cpu_pct]
      )

      summary
    ensure
      stop_resource_sampler(sampler)
      stop_backend_processes(supervisor_pids)
      stop_registered_processes
      stop_process(support_server_pid)
    end

    def enqueue_jobs(run)
      execution_ids = create_benchmark_executions!(run)
      jobs = execution_ids.map { |execution_id| BenchmarkJob.new(execution_id) }

      ActiveJob.perform_all_later(jobs)
      ensure_bulk_enqueue_succeeded!(jobs)
      update_active_job_ids!(execution_ids, jobs)
    end

    def create_benchmark_executions!(run)
      payload = payload_for_execution(run)
      now = Time.current
      rows = options.fetch(:jobs).times.map do |job_index|
        {
          benchmark_run_id: run.id,
          job_index: job_index,
          workload: options.fetch(:workload),
          payload: payload,
          enqueued_at: now,
          created_at: now,
          updated_at: now
        }
      end

      result = BenchmarkExecution.insert_all!(rows, returning: %w[id job_index])
      execution_ids_by_index = result.to_a.to_h { |row| [ row.fetch("job_index").to_i, row.fetch("id").to_i ] }

      options.fetch(:jobs).times.map do |job_index|
        execution_ids_by_index.fetch(job_index)
      end
    end

    def ensure_bulk_enqueue_succeeded!(jobs)
      failed_jobs = jobs.reject(&:successfully_enqueued?)
      return if failed_jobs.empty?

      messages = failed_jobs.map { |job| job.enqueue_error&.message || "unknown enqueue failure" }.uniq
      raise "Failed to enqueue #{failed_jobs.size} benchmark jobs: #{messages.join(', ')}"
    end

    def update_active_job_ids!(execution_ids, jobs)
      updates = jobs.each_with_index.filter_map do |job, index|
        next if job.job_id.blank?

        [ execution_ids.fetch(index), job.job_id ]
      end
      return if updates.empty?

      quoted_updated_at = BenchmarkExecution.connection.quote(Time.current)
      values_sql = updates.map do |execution_id, active_job_id|
        "(#{execution_id}, #{BenchmarkExecution.connection.quote(active_job_id)})"
      end.join(", ")

      BenchmarkExecution.connection.execute(<<~SQL)
        UPDATE benchmark_executions AS benchmark_executions
        SET active_job_id = updates.active_job_id,
            updated_at = #{quoted_updated_at}
        FROM (VALUES #{values_sql}) AS updates(id, active_job_id)
        WHERE benchmark_executions.id = updates.id
      SQL
    end

    def payload_for_execution(run = nil)
      payload = options.fetch(:payload).dup
      payload[:port] = options[:http_port] if support_server_needed?
      payload[:benchmark_run_id] = run.id if options[:workload] == "llm_stream" && run
      payload
    end

    def wait_until_complete(run)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options.fetch(:timeout_s)

      loop do
        run.reload
        executions = run.benchmark_executions
        parent_finished = executions.finished.count >= run.jobs_count
        children_finished = executions.sum(:child_jobs_finished) + executions.sum(:child_jobs_failed)
        children_enqueued = executions.sum(:child_jobs_enqueued)

        return if parent_finished && (!workload_has_child_jobs?(run.workload) || children_finished >= children_enqueued)

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise "Timed out waiting for benchmark run #{run.id} to complete"
        end

        sleep 0.1
      end
    end

    def summarize(run, sampler)
      child_aware = workload_has_child_jobs?(run.workload)
      executions = run.benchmark_executions.order(:job_index).to_a
      successful_executions = executions.select { |execution| successful_execution?(execution, child_aware:) }
      finished_executions = executions.select { |execution| end_to_end_finished_at(execution, child_aware:) }
      failed_executions = executions.select { |execution| failed_execution?(execution, child_aware:) }

      benchmark_finished_at = finished_executions.filter_map { |execution| end_to_end_finished_at(execution, child_aware:) }.max
      first_started_at = successful_executions.map(&:started_at).compact.min
      wall_time_s = elapsed_seconds(run.started_at, benchmark_finished_at)
      enqueue_time_s = elapsed_seconds(run.started_at, run.enqueued_at)
      drain_time_s = elapsed_seconds(run.enqueued_at, benchmark_finished_at)
      execution_window_s = elapsed_seconds(first_started_at, benchmark_finished_at)

      queue_delays_ms = successful_executions.filter_map do |execution|
        next unless execution.started_at

        (execution.started_at - execution.enqueued_at) * 1000.0
      end

      service_times_ms = successful_executions.filter_map do |execution|
        next unless execution.started_at && execution.finished_at

        (execution.finished_at - execution.started_at) * 1000.0
      end

      total_latencies_ms = successful_executions.filter_map do |execution|
        finished_at = end_to_end_finished_at(execution, child_aware:)
        next unless finished_at

        (finished_at - execution.enqueued_at) * 1000.0
      end

      rss_samples = sampler[:rss_samples] || []
      avg_rss_kb = rss_samples.empty? ? 0 : (rss_samples.sum.to_f / rss_samples.size).round(0)

      clk_tck = Etc.sysconf(Etc::SC_CLK_TCK).to_f
      cpu_samples = sampler[:cpu_samples] || []
      avg_cpu_pct = 0.0
      peak_cpu_pct = 0.0

      if cpu_samples.size >= 2
        first, last = cpu_samples.first, cpu_samples.last
        delta_j = last[:jiffies] - first[:jiffies]
        delta_t = last[:timestamp] - first[:timestamp]
        avg_cpu_pct = (delta_j / (delta_t * clk_tck) * 100).round(1) if delta_t > 0

        cpu_samples.each_cons(2) do |a, b|
          dj = b[:jiffies] - a[:jiffies]
          dt = b[:timestamp] - a[:timestamp]
          pct = dt > 0 ? (dj / (dt * clk_tck) * 100) : 0.0
          peak_cpu_pct = [ peak_cpu_pct, pct ].max
        end
        peak_cpu_pct = peak_cpu_pct.round(1)
      end

      successful_jobs = successful_executions.size
      finished_jobs = finished_executions.size
      failed_jobs = failed_executions.size
      child_jobs_enqueued = executions.sum(&:child_jobs_enqueued)
      child_jobs_finished = executions.sum(&:child_jobs_finished)
      child_jobs_failed = executions.sum(&:child_jobs_failed)

      {
        backend: run.backend,
        mode: run.execution_mode,
        workload: run.workload,
        jobs: run.jobs_count,
        capacity: run.capacity,
        processes: run.processes,
        db_pool: db_pool_for(run.execution_mode),
        completed_jobs: successful_jobs,
        successful_jobs: successful_jobs,
        finished_jobs: finished_jobs,
        failed_jobs: failed_jobs,
        child_jobs_enqueued: child_jobs_enqueued,
        child_jobs_finished: child_jobs_finished,
        child_jobs_failed: child_jobs_failed,
        benchmark_finished_at: benchmark_finished_at,
        wall_time_s: round_or_nil(wall_time_s),
        enqueue_time_s: round_or_nil(enqueue_time_s),
        drain_time_s: round_or_nil(drain_time_s),
        execution_window_s: round_or_nil(execution_window_s),
        jobs_per_second: jobs_per_second(successful_jobs, wall_time_s),
        finished_jobs_per_second: jobs_per_second(finished_jobs, wall_time_s),
        drain_jobs_per_second: jobs_per_second(successful_jobs, drain_time_s),
        execution_jobs_per_second: jobs_per_second(successful_jobs, execution_window_s),
        peak_rss_kb: sampler[:peak_rss_kb],
        avg_rss_kb: avg_rss_kb,
        avg_cpu_pct: avg_cpu_pct,
        peak_cpu_pct: peak_cpu_pct,
        queue_delay_ms: percentiles(queue_delays_ms),
        service_time_ms: percentiles(service_times_ms),
        total_latency_ms: percentiles(total_latencies_ms)
      }
    end

    def percentiles(values)
      sorted = values.sort
      return {} if sorted.empty?

      {
        p50: percentile(sorted, 0.50),
        p95: percentile(sorted, 0.95),
        p99: percentile(sorted, 0.99),
        max: sorted.last.round(2)
      }
    end

    def percentile(sorted_values, ratio)
      index = ((sorted_values.length - 1) * ratio).round
      sorted_values.fetch(index).round(2)
    end

    def output_path
      timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
      File.join(options.fetch(:output_dir), "#{options.fetch(:name)}-#{backend.tr('_', '-')}-#{timestamp}.json")
    end

    def start_backend_processes(mode)
      case backend
      when "solid_queue"
        [ start_solid_queue_supervisor(mode) ]
      when "async_job"
        start_async_job_workers
      else
        raise ArgumentError, "Unsupported backend: #{backend}"
      end
    end

    def start_solid_queue_supervisor(mode)
      env = {
        "RAILS_ENV" => "development",
        "BENCH_ACTIVE_JOB_ADAPTER" => "solid_queue",
        "BENCH_EXECUTION_MODE" => mode,
        "BENCH_CAPACITY" => options.fetch(:capacity).to_s,
        "BENCH_PROCESSES" => options.fetch(:processes).to_s,
        "DB_POOL" => db_pool_for(mode).to_s,
        "SOLID_QUEUE_SKIP_RECURRING" => "1"
      }.merge(database_env)

      Process.spawn(
        env,
        Gem.ruby,
        "bin/jobs",
        "start",
        chdir: Rails.root.to_s,
        out: log_file(mode),
        err: log_file(mode)
      )
    end

    def start_async_job_workers
      ready_dir = async_job_ready_dir
      FileUtils.rm_rf(ready_dir)
      FileUtils.mkdir_p(ready_dir)

      options.fetch(:processes).times.map do |index|
        ready_file = File.join(ready_dir, "worker-#{index}.ready")
        env = {
          "RAILS_ENV" => "development",
          "BENCH_ACTIVE_JOB_ADAPTER" => "async_job",
          "BENCH_CAPACITY" => options.fetch(:capacity).to_s,
          "DB_POOL" => db_pool_for("async").to_s,
          "BENCH_ASYNC_JOB_READY_FILE" => ready_file,
          "ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES" => "default"
        }.merge(database_env).merge(redis_env)

        Process.spawn(
          env,
          Gem.ruby,
          Rails.root.join("script/async_job_server").to_s,
          chdir: Rails.root.to_s,
          out: log_file("async-job-#{index}"),
          err: log_file("async-job-#{index}")
        )
      end
    end

    def start_support_server_if_needed
      return unless support_server_needed?

      port = options.fetch(:http_port)
      env = database_env.merge(support_server_env)
      pid = Process.spawn(
        env,
        Gem.ruby,
        Rails.root.join("script/delay_server").to_s,
        port.to_s,
        out: log_file("delay-server"),
        err: log_file("delay-server")
      )
      wait_for_tcp_port(port)
      pid
    end

    def support_server_env
      return {} unless options[:workload] == "ruby_llm_stream"

      {
        "BENCH_FAKE_LLM_TOKEN_COUNT" => options.dig(:payload, :token_count).to_s,
        "BENCH_FAKE_LLM_TOKEN_DELAY_MS" => options.dig(:payload, :token_delay_ms).to_s
      }
    end

    def db_pool_for(mode)
      return options.fetch(:capacity) + 5 if backend == "async_job"

      if mode == "thread"
        options.fetch(:capacity) + 5
      else
        [ 5, options.fetch(:processes) + 4 ].max
      end
    end

    def database_env
      password = ENV["DB_PASSWORD"] || ENV["POSTGRES_PASSWORD"]

      {
        "DB_HOST" => ENV.fetch("DB_HOST", "127.0.0.1"),
        "DB_PORT" => ENV.fetch("DB_PORT", "5432"),
        "DB_USER" => ENV.fetch("DB_USER", ENV.fetch("POSTGRES_USER", "chatwithwork"))
      }.tap do |env|
        env["DB_PASSWORD"] = password if password && !password.empty?
      end
    end

    def wait_for_benchmark_processes!(supervisor_pids)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options.fetch(:process_ready_timeout_s, PROCESS_READY_TIMEOUT)

      loop do
        return if backend_processes_ready?(supervisor_pids)

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise "Timed out waiting for #{backend} workers to become ready"
        end

        sleep 0.05
      end
    end

    def elapsed_seconds(start_time, end_time)
      return unless start_time && end_time

      end_time - start_time
    end

    def successful_execution?(execution, child_aware:)
      return false unless execution.finished_at.present? && execution.error_class.blank?
      return true unless child_aware

      execution.child_jobs_failed.zero? &&
        execution.child_jobs_finished == execution.child_jobs_enqueued
    end

    def failed_execution?(execution, child_aware:)
      execution.error_class.present? || (child_aware && execution.child_jobs_failed.positive?)
    end

    def end_to_end_finished_at(execution, child_aware:)
      return execution.finished_at unless child_aware

      [ execution.finished_at, execution.last_child_finished_at ].compact.max
    end

    def round_or_nil(value, digits = 3)
      value&.round(digits)
    end

    def jobs_per_second(job_count, duration_s)
      return 0.0 unless duration_s&.positive?

      (job_count / duration_s).round(2)
    end

    def log_file(name)
      Rails.root.join("log/#{backend}-#{name}.log").to_s
    end

    def wait_for_tcp_port(port, timeout: 2.0)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      loop do
        Socket.tcp("127.0.0.1", port, connect_timeout: 0.1) { |socket| socket.close }
        return
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        raise "Delay server failed to start on port #{port}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    def start_resource_sampler(supervisor_pids)
      state = { peak_rss_kb: 0, rss_samples: [], cpu_samples: [], running: true }

      state[:thread] = Thread.new do
        while state[:running]
          pids = worker_pids(supervisor_pids)
          timestamp = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          rss = pids.sum { |pid| current_rss_kb(pid) }
          state[:peak_rss_kb] = [ state[:peak_rss_kb], rss ].max
          state[:rss_samples] << rss

          jiffies = pids.sum { |pid| current_cpu_jiffies(pid) }
          state[:cpu_samples] << { timestamp: timestamp, jiffies: jiffies }

          sleep SAMPLE_INTERVAL
        end
      end

      state
    end

    def stop_resource_sampler(state)
      return unless state

      state[:running] = false
      state[:thread]&.join
    end

    def worker_pids(supervisor_pids)
      case backend
      when "solid_queue"
        SolidQueue::Process.where(kind: "Worker").pluck(:pid)
      when "async_job"
        Array(supervisor_pids).select { |pid| process_alive?(pid) }
      else
        []
      end
    rescue StandardError
      []
    end

    def current_rss_kb(pid)
      status = File.read("/proc/#{pid}/status")
      status[/^VmRSS:\s+(\d+)\s+kB$/m, 1].to_i
    rescue Errno::ENOENT
      0
    end

    def current_cpu_jiffies(pid)
      stat = File.read("/proc/#{pid}/stat")
      fields = stat[stat.rindex(")") + 2..].split
      fields[11].to_i + fields[12].to_i # utime + stime
    rescue Errno::ENOENT, Errno::ESRCH
      0
    end

    def stop_process(pid)
      return unless pid

      Process.kill("TERM", pid)
      wait_for_process_exit(pid)
    rescue Errno::ESRCH
    end

    def cleanup_benchmark_tables
      tables = ActiveRecord::Base.connection.tables
      truncate_tables!(
        tables.grep(/\Asolid_queue_/) +
        tables.grep(/\A(chats|messages|tool_calls)\z/)
      )
      cleanup_async_job_state
    end

    def support_server_needed?
      %w[http async_http ruby_llm_stream].include?(options[:workload])
    end

    def workload_has_child_jobs?(workload)
      %w[llm_stream ruby_llm_stream].include?(workload)
    end

    def truncate_tables!(tables)
      return if tables.empty?

      quoted = tables.map { |table| ActiveRecord::Base.connection.quote_table_name(table) }.join(", ")
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{quoted} RESTART IDENTITY CASCADE")
    end

    def ensure_database_ready!
      missing_tables = required_tables.reject { |table| ActiveRecord::Base.connection.data_source_exists?(table) }
      missing_columns = required_columns.each_with_object({}) do |(table, columns), hash|
        klass = table_model(table)
        klass.reset_column_information
        absent = columns - klass.column_names
        hash[table] = absent if absent.any?
      end

      return if missing_tables.empty? && missing_columns.empty?

      details = []
      details << "missing tables: #{missing_tables.join(', ')}" if missing_tables.any?
      missing_columns.each do |table, columns|
        details << "missing columns on #{table}: #{columns.join(', ')}"
      end

      raise <<~MSG.strip
        Benchmark database is not up to date (#{details.join('; ')}).
        Run `bin/rails db:prepare`.
        If Solid Queue tables are missing, also run:
        `bin/rails runner 'unless ActiveRecord::Base.connection.table_exists?(\"solid_queue_jobs\"); load Rails.root.join(\"db/queue_schema.rb\"); end'`
      MSG
    end

    def stop_registered_processes
      registered_process_pids.each do |pid|
        next if pid == Process.pid

        stop_process(pid)
      end
    rescue StandardError
    end

    def registered_process_pids
      SolidQueue::Process.pluck(:pid).uniq
    end

    def wait_for_process_exit(pid, timeout: PROCESS_STOP_TIMEOUT)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      loop do
        waited_pid = Process.waitpid(pid, Process::WNOHANG)
        return if waited_pid

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          Process.kill("KILL", pid)
          Process.waitpid(pid)
          return
        end

        sleep 0.05
      rescue Errno::ESRCH
        return
      rescue Errno::ECHILD
        return
      end
    end

    def cleanup_async_job_state
      return unless backend == "async_job"

      redis_service.flushdb!
    end

    def ensure_backend_dependencies!
      return unless backend == "async_job"

      redis_service.ensure_available!
    end

    def backend_processes_ready?(supervisor_pids)
      case backend
      when "solid_queue"
        counts = SolidQueue::Process.group(:kind).count
        counts.fetch("Worker", 0) >= options.fetch(:processes) &&
          counts.fetch("Dispatcher", 0) >= 1
      when "async_job"
        ready_files = Dir.glob(File.join(async_job_ready_dir, "*.ready"))
        ready_files.size >= options.fetch(:processes) &&
          Array(supervisor_pids).all? { |pid| process_alive?(pid) }
      else
        false
      end
    end

    def required_tables
      tables = %w[benchmark_runs benchmark_executions]
      tables += %w[solid_queue_processes solid_queue_jobs] if backend == "solid_queue"
      tables += %w[chats messages models tool_calls] if options[:workload] == "ruby_llm_stream"
      tables
    end

    def required_columns
      columns = {
        "benchmark_runs" => %w[backend],
        "benchmark_executions" => %w[
          child_jobs_enqueued
          child_jobs_finished
          child_jobs_failed
          last_child_enqueued_at
          last_child_finished_at
        ]
      }
      columns["chats"] = %w[benchmark_execution_id] if options[:workload] == "ruby_llm_stream"
      columns
    end

    def table_model(table)
      case table
      when "benchmark_runs" then BenchmarkRun
      when "benchmark_executions" then BenchmarkExecution
      when "chats" then Chat
      else
        raise ArgumentError, "No model mapping for #{table}"
      end
    end

    def stop_backend_processes(supervisor_pids)
      Array(supervisor_pids).each { |pid| stop_process(pid) }
      FileUtils.rm_rf(async_job_ready_dir) if backend == "async_job"
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def set_active_job_queue_adapter!
      ActiveJob::Base.queue_adapter = backend.to_sym
    end

    def validate_backend_mode!(mode)
      return unless backend == "async_job" && mode != "async"

      raise ArgumentError, "Async::Job only supports mode=async in this benchmark family"
    end

    def redis_service
      @redis_service ||= Bench::AsyncJob::RedisService.new
    end

    def redis_env
      redis_config = Rails.application.config_for(:redis).with_indifferent_access

      {
        "REDIS_HOST" => redis_config.fetch(:host),
        "REDIS_PORT" => redis_config.fetch(:port).to_s,
        "REDIS_DB" => redis_config.fetch(:db).to_s,
        "REDIS_PREFIX" => redis_config.fetch(:prefix)
      }.tap do |env|
        env["REDIS_PASSWORD"] = redis_config[:password] if redis_config[:password].present?
      end
    end

    def async_job_ready_dir
      @async_job_ready_dir ||= Dir.mktmpdir("async-job-ready-", Rails.root.join("tmp"))
    end

    def backend
      options.fetch(:backend, "solid_queue")
    end
  end
end
