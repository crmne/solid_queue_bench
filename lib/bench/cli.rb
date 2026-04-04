require "fileutils"
require "optparse"

module Bench
  class CLI
    DEFAULTS = {
      name: "solid-queue-bench",
      backend: "solid_queue",
      modes: %w[thread async],
      workload: "sleep",
      capacity: 100,
      processes: 1,
      jobs: 1000,
      timeout_s: 300,
      process_ready_timeout_s: 30,
      output_dir: File.expand_path("../../tmp/benchmarks", __dir__),
      payload: { duration_ms: 50 },
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
          parser.on("--modes MODES", "Comma-separated list, e.g. thread,async") { |value| options[:modes] = value.split(",") }
          parser.on("--workload NAME", "sleep, cpu, http, async_http, llm_batch, llm_stream, or ruby_llm_stream") { |value| options[:workload] = value }
          parser.on("--capacity N", Integer, "Worker capacity / threads") { |value| options[:capacity] = value }
          parser.on("--processes N", Integer, "Worker process count") { |value| options[:processes] = value }
          parser.on("--jobs N", Integer, "Number of jobs to enqueue") { |value| options[:jobs] = value }
          parser.on("--duration-ms N", Integer, "Sleep or HTTP delay in ms") { |value| options[:payload][:duration_ms] = value }
          parser.on("--duration-s N", Integer, "Long wait duration in seconds") { |value| options[:payload][:duration_s] = value }
          parser.on("--iterations N", Integer, "CPU workload iterations per job") { |value| options[:payload][:iterations] = value }
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
        normalize_payload!
      end

      def normalize_backend_modes!
        case options[:backend]
        when "solid_queue"
          return
        when "async_job"
          options[:modes] = %w[async] if options[:modes] == DEFAULTS[:modes]
          invalid_modes = options[:modes] - %w[async]
          raise ArgumentError, "Async::Job only supports mode=async" if invalid_modes.any?
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
        else
          raise ArgumentError, "Unsupported workload: #{options[:workload]}"
        end
      end
  end
end
