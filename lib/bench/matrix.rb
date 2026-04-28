require "optparse"
require "json"
require "csv"
require "fileutils"
require "shellwords"

module Bench
  class Matrix
    DEFAULTS = {
      backend: "solid_queue",
      workload: "sleep",
      jobs: 500,
      concurrencies: [ 5, 10, 25, 50, 100, 200 ],
      processes: [ 1, 2, 4 ],
      modes: %w[thread fiber],
      timeout_s: 300,
      process_ready_timeout_s: 30,
      output_dir: File.expand_path("../../tmp/benchmarks", __dir__),
      db_pool: nil,
      payload: {},
      http_port: 9393,
      name: nil,
      repeat: 1,
      failure_repeat_limit: nil,
      max_total_concurrency: nil
    }.freeze

    def initialize(argv)
      @argv = argv
      @options = Marshal.load(Marshal.dump(DEFAULTS))
    end

    def run
      parse!
      cells = build_cells
      results = sweep(cells)
      write_output(results, planned_cells: cells.size)
    end

    private
      attr_reader :argv, :options

      def parse!
        OptionParser.new do |parser|
          parser.banner = "Usage: bin/matrix [options]"

          parser.on("--backend NAME", "solid_queue or async_job (default: solid_queue)") { |v| options[:backend] = v }
          parser.on("--workload NAME", "sleep, cpu, http, async_http, llm_batch, llm_stream, ruby_llm_stream, db_queries, db_transaction, db_transaction_pool_pressure, or db_mixed (default: sleep)") { |v| options[:workload] = v }
          parser.on("--jobs N", Integer, "Jobs per cell (default: 500)") { |v| options[:jobs] = v }
          parser.on("--concurrencies LIST", "Comma-separated concurrency levels (default: 5,10,25,50,100,200)") { |v| options[:concurrencies] = v.split(",").map(&:to_i) }
          parser.on("--processes LIST", "Comma-separated process counts (default: 1,2,4)") { |v| options[:processes] = v.split(",").map(&:to_i) }
          parser.on("--modes LIST", "Comma-separated modes (default: thread,fiber)") { |v| options[:modes] = v.split(",") }
          parser.on("--duration-ms N", Integer, "Sleep, HTTP, mixed HTTP, or DB slow-query delay in ms") { |v| options[:payload][:duration_ms] = v }
          parser.on("--duration-s N", Integer, "Long wait duration in seconds") { |v| options[:payload][:duration_s] = v }
          parser.on("--db-pool VALUE", "DB pool policy: default, matched, mode_specific, minimum, or a positive integer") { |v| options[:db_pool] = v }
          parser.on("--iterations N", Integer, "CPU workload iterations") { |v| options[:payload][:iterations] = v }
          parser.on("--reads N", Integer, "Sequential SELECT queries per DB-heavy job") { |v| options[:payload][:reads] = v }
          parser.on("--writes N", Integer, "Write queries per DB-heavy job") { |v| options[:payload][:writes] = v }
          parser.on("--token-count N", Integer, "Streaming token count") { |v| options[:payload][:token_count] = v }
          parser.on("--token-delay-ms N", Integer, "Streaming token delay in ms") { |v| options[:payload][:token_delay_ms] = v }
          parser.on("--llm-model MODEL", "RubyLLM model id (default: gpt-4.1-mini)") { |v| options[:payload][:model_id] = v }
          parser.on("--prompt TEXT", "Prompt to send to the LLM workload") { |v| options[:payload][:prompt] = v }
          parser.on("--timeout-s N", Integer, "Per-cell timeout in seconds (default: 300)") { |v| options[:timeout_s] = v }
          parser.on("--process-ready-timeout-s N", Integer, "Worker/dispatcher readiness timeout in seconds (default: 30)") { |v| options[:process_ready_timeout_s] = v }
          parser.on("--http-port N", Integer, "Delay server port (default: 9393)") { |v| options[:http_port] = v }
          parser.on("--output-dir PATH", "Output directory") { |v| options[:output_dir] = v }
          parser.on("--name NAME", "Run name prefix for output files") { |v| options[:name] = v }
          parser.on("--repeat N", Integer, "Runs per cell, report median (default: 1)") { |v| options[:repeat] = v }
          parser.on("--failure-repeat-limit N", Integer, "Stop retrying an all-failed repeated cell after N failed runs") { |v| options[:failure_repeat_limit] = v }
          parser.on("--max-total-concurrency N", Integer, "Skip cells where concurrency * processes exceeds N") { |v| options[:max_total_concurrency] = v }
        end.parse!(argv)

        normalize_backend_modes!
        normalize_db_pool!
        normalize_payload!
      end

      def normalize_backend_modes!
        case options[:backend]
        when "solid_queue"
          return
        when "async_job"
          options[:modes] = %w[fiber] if options[:modes] == DEFAULTS[:modes]
          invalid_modes = options[:modes] - %w[fiber]
          raise ArgumentError, "Async::Job only supports mode=fiber" if invalid_modes.any?
        else
          raise ArgumentError, "Unsupported backend: #{options[:backend]}"
        end
      end

      def normalize_payload!
        case options[:workload]
        when "sleep", "http", "async_http"
          options[:payload] = { duration_ms: options[:payload][:duration_ms] || 50 }
        when "cpu"
          options[:payload] = { iterations: options[:payload][:iterations] || 25_000 }
        when "llm_batch"
          options[:payload] = { duration_s: options[:payload][:duration_s] || 5 }
        when "llm_stream"
          options[:payload] = {
            token_count: options[:payload][:token_count] || 100,
            token_delay_ms: options[:payload][:token_delay_ms] || 30
          }
        when "ruby_llm_stream"
          options[:payload] = {
            token_count: options[:payload][:token_count] || 80,
            token_delay_ms: options[:payload][:token_delay_ms] || 20,
            model_id: options[:payload][:model_id] || "gpt-4.1-mini",
            prompt: options[:payload][:prompt] || "Respond with a concise sentence."
          }
        when "db_queries", "db_transaction", "db_transaction_pool_pressure"
          options[:payload] = {
            reads: options[:payload][:reads] || 10,
            writes: options[:payload][:writes] || 2,
            duration_ms: options[:payload][:duration_ms] || 0
          }
          options[:db_pool] ||= :matched if options[:workload] == "db_transaction"
          options[:db_pool] ||= :mode_specific if options[:workload] == "db_transaction_pool_pressure"
        when "db_mixed"
          options[:payload] = {
            reads: options[:payload][:reads] || 10,
            writes: options[:payload][:writes] || 2,
            duration_ms: options[:payload][:duration_ms] || 50
          }
        else
          raise ArgumentError, "Unsupported workload: #{options[:workload]}"
        end
      end

      def normalize_db_pool!
        return if options[:db_pool].nil?

        value = options[:db_pool].to_s.strip.downcase
        options[:db_pool] = if value == "default"
          :default
        elsif value == "minimum"
          :minimum
        elsif value == "matched"
          :matched
        elsif %w[mode_specific mode-specific modespecific].include?(value)
          :mode_specific
        elsif value.match?(/\A\d+\z/) && Integer(value).positive?
          Integer(value)
        else
          raise ArgumentError, "--db-pool must be default, matched, mode_specific, minimum, or a positive integer"
        end
      end

      def sweep(cells = build_cells)
        total = cells.size

        puts "Matrix sweep: #{total} cells"
        puts "  Backend:    #{options[:backend]}"
        puts "  Modes:      #{options[:modes].join(", ")}"
        puts "  Concurrencies: #{options[:concurrencies].join(", ")}"
        puts "  Processes:  #{options[:processes].join(", ")}"
        puts "  DB Pool:    #{serialize_db_pool_option(options[:db_pool])}" if options[:db_pool]
        if options[:max_total_concurrency]
          puts "  Max Slots:  #{options[:max_total_concurrency]} (concurrency * processes)"
        end
        puts "  Workload:   #{options[:workload]} (#{options[:payload].map { |k, v| "#{k}=#{v}" }.join(", ")})"
        puts "  Jobs/cell:  #{options[:jobs]}"
        puts "  Repeat:     #{options[:repeat]}x (median)" if options[:repeat] > 1
        puts "  Fail limit: #{options[:failure_repeat_limit]} failed run(s) per all-failed cell" if options[:failure_repeat_limit]
        puts "-" * 72

        cells.each_with_index.map do |cell, index|
          mode, concurrency, procs = cell
          label = "[#{index + 1}/#{total}] mode=#{mode} concurrency=#{concurrency} processes=#{procs}"
          puts "\n#{label}"

          runner_opts = {
            name: run_name(mode, concurrency, procs),
            backend: options[:backend],
            modes: [ mode ],
            workload: options[:workload],
            concurrency: concurrency,
            processes: procs,
            jobs: options[:jobs],
            timeout_s: options[:timeout_s],
            process_ready_timeout_s: options[:process_ready_timeout_s],
            db_pool: options[:db_pool],
            payload: options[:payload],
            http_port: options[:http_port],
            output_dir: options[:output_dir]
          }

          result = run_cell(mode, runner_opts)

          puts "  -> #{result[:jobs_per_second]} successful jobs/s | success=#{result[:successful_jobs]}/#{options[:jobs]} failed=#{result[:failed_jobs]} | RSS peak=#{result[:peak_rss_kb]}KB avg=#{result[:avg_rss_kb]}KB | CPU avg=#{result[:avg_cpu_pct]}% peak=#{result[:peak_cpu_pct]}%"
          result
        rescue => error
          puts "  !! FAILED: #{error.message.lines.first&.strip}"
          nil
        end.compact
      end

      def build_cells
        options[:modes].flat_map do |mode|
          options[:processes].flat_map do |procs|
            options[:concurrencies].map do |cap|
              [ mode, cap, procs ]
            end
          end
        end.filter do |_mode, cap, procs|
          next true unless options[:max_total_concurrency]

          (cap * procs) <= options[:max_total_concurrency]
        end
      end

      def run_cell(mode, runner_opts)
        repeats = options[:repeat]
        return Bench::Runner.new(runner_opts).run_single(mode) if repeats <= 1

        runs = []
        failed_runs = 0

        repeats.times do |i|
          puts "    run #{i + 1}/#{repeats}..." if repeats > 1
          runs << Bench::Runner.new(runner_opts).run_single(mode)
        rescue => error
          failed_runs += 1
          puts "    run #{i + 1} failed: #{error.message.lines.first&.strip}"

          if runs.empty? && options[:failure_repeat_limit] && failed_runs >= options[:failure_repeat_limit]
            puts "    stopping cell after #{failed_runs} failed run(s)"
            break
          end
        end

        raise "No successful runs (#{failed_runs}/#{repeats} attempted)" if runs.empty?

        median_result(runs)
      end

      def median_result(runs)
        sorted = runs.sort_by do |run|
          [
            run[:jobs_per_second] || 0.0,
            run[:execution_jobs_per_second] || 0.0,
            run[:successful_jobs] || 0,
            -(run[:failed_jobs] || 0)
          ]
        end
        representative = Marshal.load(Marshal.dump(sorted[sorted.size / 2]))
        representative[:repeat_jobs_per_second_values] = runs.map { |run| run[:jobs_per_second] }.sort
        representative[:repeat_successful_jobs_values] = runs.map { |run| run[:successful_jobs] }.sort
        representative
      end

      def run_name(mode, concurrency, procs)
        prefix = options[:name] || "matrix"
        "#{prefix}-#{mode}-c#{concurrency}-proc#{procs}"
      end

      def write_output(results, planned_cells:)
        FileUtils.mkdir_p(options[:output_dir])
        timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
        base = "#{options[:name] || "matrix"}-#{options[:backend].tr('_', '-')}-#{options[:workload]}-#{timestamp}"

        json_output = {
          generated_at: Time.current.iso8601,
          ruby_version: RUBY_VERSION,
          isolation_level: ActiveSupport::IsolatedExecutionState.isolation_level,
          backend: options[:backend],
          workload: options[:workload],
          payload: options[:payload],
          jobs_per_cell: options[:jobs],
          concurrencies: options[:concurrencies],
          processes: options[:processes],
          modes: options[:modes],
          repeat: options[:repeat],
          db_pool: serialize_db_pool_option(options[:db_pool]),
          max_total_concurrency: options[:max_total_concurrency],
          planned_cells: planned_cells,
          successful_cells: results.size,
          failed_cells: planned_cells - results.size,
          results: results
        }
        if options[:backend] == "solid_queue" && (revision = solid_queue_revision)
          json_output[:solid_queue_revision] = revision
        end

        json_path = File.join(options[:output_dir], "#{base}.json")
        File.write(json_path, JSON.pretty_generate(json_output))

        csv_path = File.join(options[:output_dir], "#{base}.csv")
        write_csv(csv_path, results)

        puts "\n#{"=" * 72}"
        puts "Matrix sweep complete: #{results.size}/#{planned_cells} cells"
        puts "Failed cells: #{planned_cells - results.size}" if results.size < planned_cells
        puts "JSON: #{json_path}"
        puts "CSV:  #{csv_path}"

        generate_charts(csv_path)
      end

      def generate_charts(csv_path)
        plot_script = File.expand_path("../../bin/plot", __dir__)
        return unless File.exist?(plot_script)

        puts "\nGenerating charts..."
        system("ruby", plot_script, csv_path, "--output-dir", options[:output_dir])
      end

      def write_csv(path, results)
        CSV.open(path, "w") do |csv|
          csv << csv_headers
          results.each { |r| csv << csv_row(r) }
        end
      end

      def csv_headers
        %w[
          backend mode workload jobs concurrency processes db_pool
          jobs_per_second finished_jobs_per_second drain_jobs_per_second execution_jobs_per_second
          wall_time_s enqueue_time_s drain_time_s execution_window_s
          completed_jobs successful_jobs finished_jobs failed_jobs
          child_jobs_enqueued child_jobs_finished child_jobs_failed
          peak_rss_kb avg_rss_kb avg_cpu_pct peak_cpu_pct
          queue_delay_p50_ms queue_delay_p95_ms queue_delay_p99_ms queue_delay_max_ms
          service_time_p50_ms service_time_p95_ms service_time_p99_ms service_time_max_ms
          total_latency_p50_ms total_latency_p95_ms total_latency_p99_ms total_latency_max_ms
        ]
      end

      def csv_row(r)
        [
          r[:backend], r[:mode], r[:workload], r[:jobs], r[:concurrency], r[:processes], r[:db_pool],
          r[:jobs_per_second], r[:finished_jobs_per_second], r[:drain_jobs_per_second], r[:execution_jobs_per_second],
          r[:wall_time_s], r[:enqueue_time_s], r[:drain_time_s], r[:execution_window_s],
          r[:completed_jobs], r[:successful_jobs], r[:finished_jobs], r[:failed_jobs],
          r[:child_jobs_enqueued], r[:child_jobs_finished], r[:child_jobs_failed],
          r[:peak_rss_kb], r[:avg_rss_kb], r[:avg_cpu_pct], r[:peak_cpu_pct],
          *pct_values(r[:queue_delay_ms]),
          *pct_values(r[:service_time_ms]),
          *pct_values(r[:total_latency_ms])
        ]
      end

      def pct_values(hash)
        return [ nil, nil, nil, nil ] if hash.nil? || hash.empty?
        [ hash[:p50], hash[:p95], hash[:p99], hash[:max] ]
      end

      def serialize_db_pool_option(value)
        case value
        when :matched then "matched"
        when :mode_specific then "mode_specific"
        when :default then "default"
        else value
        end
      end

      def solid_queue_revision
        repo = File.expand_path("../../../solid_queue", __dir__)
        return unless Dir.exist?(repo)

        sha = `git -C #{Shellwords.escape(repo)} rev-parse HEAD 2>/dev/null`.strip
        sha unless sha.empty?
      end
  end
end
