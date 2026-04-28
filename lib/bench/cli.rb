require "fileutils"
require "optparse"

module Bench
  class CLI
    DEFAULTS = {
      name: "solid-queue-bench",
      backend: "solid_queue",
      modes: %w[thread fiber],
      workload: "sleep",
      concurrency: 100,
      processes: 1,
      jobs: 1000,
      timeout_s: 300,
      process_ready_timeout_s: 30,
      output_dir: File.expand_path("../../tmp/benchmarks", __dir__),
      db_pool: nil,
      payload: {},
      http_port: 9393
    }.freeze

    def initialize(argv)
      @argv = argv
      @options = Marshal.load(Marshal.dump(DEFAULTS))
    end

    def run
      parse!
      Bench::Runner.new(options).compare
    end

    private
      attr_reader :argv, :options

      def parse!
        OptionParser.new do |parser|
          parser.banner = "Usage: bin/benchmark [options]"

          parser.on("--name NAME", "Benchmark run name") { |value| options[:name] = value }
          parser.on("--backend NAME", "solid_queue or async_job (default: solid_queue)") { |value| options[:backend] = value }
          parser.on("--modes MODES", "Comma-separated list, e.g. thread,fiber") { |value| options[:modes] = value.split(",") }
          parser.on("--workload NAME", "sleep, cpu, http, async_http, llm_batch, llm_stream, ruby_llm_stream, db_queries, db_transaction, db_transaction_pool_pressure, or db_mixed") { |value| options[:workload] = value }
          parser.on("--concurrency N", Integer, "Concurrent jobs per worker process") { |value| options[:concurrency] = value }
          parser.on("--processes N", Integer, "Worker process count") { |value| options[:processes] = value }
          parser.on("--jobs N", Integer, "Number of jobs to enqueue") { |value| options[:jobs] = value }
          parser.on("--duration-ms N", Integer, "Sleep, HTTP, mixed HTTP, or DB slow-query delay in ms") { |value| options[:payload][:duration_ms] = value }
          parser.on("--duration-s N", Integer, "Long wait duration in seconds") { |value| options[:payload][:duration_s] = value }
          parser.on("--db-pool VALUE", "DB pool policy: default, matched, mode_specific, minimum, or a positive integer") { |value| options[:db_pool] = value }
          parser.on("--iterations N", Integer, "CPU workload iterations per job") { |value| options[:payload][:iterations] = value }
          parser.on("--reads N", Integer, "Sequential SELECT queries per DB-heavy job") { |value| options[:payload][:reads] = value }
          parser.on("--writes N", Integer, "Write queries per DB-heavy job") { |value| options[:payload][:writes] = value }
          parser.on("--token-count N", Integer, "Streaming token count") { |value| options[:payload][:token_count] = value }
          parser.on("--token-delay-ms N", Integer, "Streaming token delay in ms") { |value| options[:payload][:token_delay_ms] = value }
          parser.on("--llm-model MODEL", "RubyLLM model id (default: gpt-4.1-mini)") { |value| options[:payload][:model_id] = value }
          parser.on("--prompt TEXT", "Prompt to send to the LLM workload") { |value| options[:payload][:prompt] = value }
          parser.on("--timeout-s N", Integer, "Benchmark timeout in seconds") { |value| options[:timeout_s] = value }
          parser.on("--process-ready-timeout-s N", Integer, "Worker/dispatcher readiness timeout in seconds") { |value| options[:process_ready_timeout_s] = value }
          parser.on("--http-port N", Integer, "Local delay server port for HTTP workload") { |value| options[:http_port] = value }
          parser.on("--output-dir PATH", "Where to write JSON result files") { |value| options[:output_dir] = value }
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
  end
end
