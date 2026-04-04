require "optparse"
require "json"
require "csv"
require "fileutils"

module Bench
  class Matrix
    DEFAULTS = {
      workload: "sleep",
      jobs: 500,
      capacities: [ 5, 10, 25, 50, 100, 200 ],
      processes: [ 1, 2, 4 ],
      modes: %w[thread async],
      timeout_s: 300,
      output_dir: File.expand_path("../../tmp/benchmarks", __dir__),
      payload: { duration_ms: 50 },
      http_port: 9393,
      name: nil,
      repeat: 1
    }.freeze

    def initialize(argv)
      @argv = argv
      @options = Marshal.load(Marshal.dump(DEFAULTS))
    end

    def run
      parse!
      results = sweep
      write_output(results)
    end

    private
      attr_reader :argv, :options

      def parse!
        OptionParser.new do |parser|
          parser.banner = "Usage: bin/matrix [options]"

          parser.on("--workload NAME", "sleep, cpu, http, or async_http (default: sleep)") { |v| options[:workload] = v }
          parser.on("--jobs N", Integer, "Jobs per cell (default: 500)") { |v| options[:jobs] = v }
          parser.on("--capacities LIST", "Comma-separated capacities (default: 5,10,25,50,100,200)") { |v| options[:capacities] = v.split(",").map(&:to_i) }
          parser.on("--processes LIST", "Comma-separated process counts (default: 1,2,4)") { |v| options[:processes] = v.split(",").map(&:to_i) }
          parser.on("--modes LIST", "Comma-separated modes (default: thread,async)") { |v| options[:modes] = v.split(",") }
          parser.on("--duration-ms N", Integer, "Sleep/HTTP delay in ms (default: 50)") { |v| options[:payload][:duration_ms] = v }
          parser.on("--iterations N", Integer, "CPU workload iterations") { |v| options[:payload][:iterations] = v }
          parser.on("--timeout-s N", Integer, "Per-cell timeout in seconds (default: 300)") { |v| options[:timeout_s] = v }
          parser.on("--http-port N", Integer, "Delay server port (default: 9393)") { |v| options[:http_port] = v }
          parser.on("--output-dir PATH", "Output directory") { |v| options[:output_dir] = v }
          parser.on("--name NAME", "Run name prefix for output files") { |v| options[:name] = v }
          parser.on("--repeat N", Integer, "Runs per cell, report median (default: 1)") { |v| options[:repeat] = v }
        end.parse!(argv)

        normalize_payload!
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
        else
          raise ArgumentError, "Unsupported workload: #{options[:workload]}"
        end
      end

      def sweep
        cells = build_cells
        total = cells.size

        puts "Matrix sweep: #{total} cells"
        puts "  Modes:      #{options[:modes].join(", ")}"
        puts "  Capacities: #{options[:capacities].join(", ")}"
        puts "  Processes:  #{options[:processes].join(", ")}"
        puts "  Workload:   #{options[:workload]} (#{options[:payload].map { |k, v| "#{k}=#{v}" }.join(", ")})"
        puts "  Jobs/cell:  #{options[:jobs]}"
        puts "  Repeat:     #{options[:repeat]}x (median)" if options[:repeat] > 1
        puts "-" * 72

        cells.each_with_index.map do |cell, index|
          mode, capacity, procs = cell
          label = "[#{index + 1}/#{total}] mode=#{mode} capacity=#{capacity} processes=#{procs}"
          puts "\n#{label}"

          runner_opts = {
            name: run_name(mode, capacity, procs),
            modes: [ mode ],
            workload: options[:workload],
            capacity: capacity,
            processes: procs,
            jobs: options[:jobs],
            timeout_s: options[:timeout_s],
            payload: options[:payload],
            http_port: options[:http_port],
            output_dir: options[:output_dir]
          }

          result = run_cell(mode, runner_opts)

          puts "  -> #{result[:jobs_per_second]} jobs/s | RSS peak=#{result[:peak_rss_kb]}KB avg=#{result[:avg_rss_kb]}KB | CPU avg=#{result[:avg_cpu_pct]}% peak=#{result[:peak_cpu_pct]}%"
          result
        rescue => error
          puts "  !! FAILED: #{error.message.lines.first&.strip}"
          nil
        end.compact
      end

      def build_cells
        options[:modes].flat_map do |mode|
          options[:processes].flat_map do |procs|
            options[:capacities].map do |cap|
              [ mode, cap, procs ]
            end
          end
        end
      end

      def run_cell(mode, runner_opts)
        repeats = options[:repeat]
        return Bench::Runner.new(runner_opts).run_single(mode) if repeats <= 1

        runs = repeats.times.filter_map do |i|
          puts "    run #{i + 1}/#{repeats}..." if repeats > 1
          Bench::Runner.new(runner_opts).run_single(mode)
        rescue => error
          puts "    run #{i + 1} failed: #{error.message.lines.first&.strip}"
          nil
        end

        raise "All #{repeats} runs failed" if runs.empty?

        median_result(runs)
      end

      def median_result(runs)
        sorted = runs.sort_by { |r| r[:jobs_per_second] }
        median = sorted[sorted.size / 2]

        numeric_keys = %i[jobs_per_second wall_time_s peak_rss_kb avg_rss_kb avg_cpu_pct peak_cpu_pct]
        result = median.dup

        numeric_keys.each do |key|
          values = runs.map { |r| r[key] }.compact.sort
          result[key] = values[values.size / 2]
        end

        result
      end

      def run_name(mode, capacity, procs)
        prefix = options[:name] || "matrix"
        "#{prefix}-#{mode}-cap#{capacity}-proc#{procs}"
      end

      def write_output(results)
        FileUtils.mkdir_p(options[:output_dir])
        timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
        base = "#{options[:name] || "matrix"}-#{options[:workload]}-#{timestamp}"

        json_output = {
          generated_at: Time.current.iso8601,
          ruby_version: RUBY_VERSION,
          isolation_level: ActiveSupport::IsolatedExecutionState.isolation_level,
          workload: options[:workload],
          payload: options[:payload],
          jobs_per_cell: options[:jobs],
          capacities: options[:capacities],
          processes: options[:processes],
          modes: options[:modes],
          repeat: options[:repeat],
          results: results
        }

        json_path = File.join(options[:output_dir], "#{base}.json")
        File.write(json_path, JSON.pretty_generate(json_output))

        csv_path = File.join(options[:output_dir], "#{base}.csv")
        write_csv(csv_path, results)

        puts "\n#{"=" * 72}"
        puts "Matrix sweep complete: #{results.size} cells"
        puts "JSON: #{json_path}"
        puts "CSV:  #{csv_path}"

        generate_charts(csv_path)
      end

      def generate_charts(csv_path)
        plot_script = File.expand_path("../../bin/plot", __dir__)
        return unless File.exist?(plot_script)

        puts "\nGenerating charts..."
        system("python3", plot_script, csv_path, "--output-dir", options[:output_dir])
      end

      def write_csv(path, results)
        CSV.open(path, "w") do |csv|
          csv << csv_headers
          results.each { |r| csv << csv_row(r) }
        end
      end

      def csv_headers
        %w[
          mode capacity processes db_pool
          jobs_per_second wall_time_s completed_jobs failed_jobs
          peak_rss_kb avg_rss_kb avg_cpu_pct peak_cpu_pct
          queue_delay_p50_ms queue_delay_p95_ms queue_delay_p99_ms queue_delay_max_ms
          service_time_p50_ms service_time_p95_ms service_time_p99_ms service_time_max_ms
          total_latency_p50_ms total_latency_p95_ms total_latency_p99_ms total_latency_max_ms
        ]
      end

      def csv_row(r)
        [
          r[:mode], r[:capacity], r[:processes], r[:db_pool],
          r[:jobs_per_second], r[:wall_time_s], r[:completed_jobs], r[:failed_jobs],
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
  end
end
