require "json"
require "rbconfig"
require "fileutils"
require "socket"
require "etc"

module Bench
  class Runner
    SAMPLE_INTERVAL = 0.1

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
        cleanup_queue_tables
        delay_server_pid = start_delay_server_if_needed

        run = BenchmarkRun.create!(
          name: options.fetch(:name),
          execution_mode: mode,
          workload: options.fetch(:workload),
          capacity: options.fetch(:capacity),
          processes: options.fetch(:processes),
          jobs_count: options.fetch(:jobs),
          payload: options.fetch(:payload),
          started_at: Time.current
        )

        supervisor_pid = start_supervisor(mode)
        sampler = start_resource_sampler
        enqueue_jobs(run)
        run.update!(enqueued_at: Time.current)
        wait_until_complete(run)
        stop_resource_sampler(sampler)

        summary = summarize(run, sampler)
        run.update!(
          completed_at: Time.current,
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
        stop_process(supervisor_pid)
        stop_process(delay_server_pid)
      end

      def enqueue_jobs(run)
        options.fetch(:jobs).times do |job_index|
          execution = run.benchmark_executions.create!(
            job_index: job_index,
            workload: options.fetch(:workload),
            payload: payload_for_execution,
            enqueued_at: Time.current
          )

          job = BenchmarkJob.perform_later(execution.id)
          execution.update_columns(active_job_id: job.job_id)
        end
      end

      def payload_for_execution
        payload = options.fetch(:payload).dup
        payload[:port] = options[:http_port] if options[:workload].match?(/\Ahttp|async_http\z/)
        payload
      end

      def wait_until_complete(run)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options.fetch(:timeout_s)

        loop do
          run.reload
          return if run.benchmark_executions.completed.count >= run.jobs_count

          if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            raise "Timed out waiting for benchmark run #{run.id} to complete"
          end

          sleep 0.1
        end
      end

      def summarize(run, sampler)
        executions = run.benchmark_executions.order(:job_index).to_a
        wall_time_s = executions.map(&:finished_at).compact.max - run.started_at
        completed = executions.count { |execution| execution.finished_at.present? }

        queue_delays_ms = executions.filter_map do |execution|
          next unless execution.started_at

          (execution.started_at - execution.enqueued_at) * 1000.0
        end

        service_times_ms = executions.filter_map do |execution|
          next unless execution.started_at && execution.finished_at

          (execution.finished_at - execution.started_at) * 1000.0
        end

        total_latencies_ms = executions.filter_map do |execution|
          next unless execution.finished_at

          (execution.finished_at - execution.enqueued_at) * 1000.0
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

        {
          mode: run.execution_mode,
          workload: run.workload,
          jobs: run.jobs_count,
          capacity: run.capacity,
          processes: run.processes,
          db_pool: db_pool_for(run.execution_mode),
          completed_jobs: completed,
          failed_jobs: executions.count { |execution| execution.error_class.present? },
          wall_time_s: wall_time_s.round(3),
          jobs_per_second: (completed / wall_time_s).round(2),
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
        File.join(options.fetch(:output_dir), "#{options.fetch(:name)}-#{timestamp}.json")
      end

      def start_supervisor(mode)
        env = {
          "RAILS_ENV" => "development",
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

      def start_delay_server_if_needed
        return unless options[:workload].match?(/\Ahttp|async_http\z/)

        port = options.fetch(:http_port)
        env = database_env
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

      def db_pool_for(mode)
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

      def log_file(name)
        Rails.root.join("log/#{name}.log").to_s
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

      def start_resource_sampler
        state = { peak_rss_kb: 0, rss_samples: [], cpu_samples: [], running: true }

        state[:thread] = Thread.new do
          while state[:running]
            pids = worker_pids
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

      def worker_pids
        SolidQueue::Process.where(kind: "Worker").pluck(:pid)
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
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
      end

      def cleanup_queue_tables
        truncate_tables!(ActiveRecord::Base.connection.tables.grep(/\Asolid_queue_/))
      end

      def truncate_tables!(tables)
        return if tables.empty?

        quoted = tables.map { |table| ActiveRecord::Base.connection.quote_table_name(table) }.join(", ")
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{quoted} RESTART IDENTITY CASCADE")
      end
  end
end
