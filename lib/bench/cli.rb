require "fileutils"
require "optparse"

module Bench
  class CLI
    DEFAULTS = {
      name: "solid-queue-bench",
      modes: %w[thread async],
      workload: "sleep",
      capacity: 100,
      processes: 1,
      jobs: 1000,
      timeout_s: 300,
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
          parser.on("--modes MODES", "Comma-separated list, e.g. thread,async") { |value| options[:modes] = value.split(",") }
          parser.on("--workload NAME", "sleep, cpu, or http") { |value| options[:workload] = value }
          parser.on("--capacity N", Integer, "Worker capacity / threads") { |value| options[:capacity] = value }
          parser.on("--processes N", Integer, "Worker process count") { |value| options[:processes] = value }
          parser.on("--jobs N", Integer, "Number of jobs to enqueue") { |value| options[:jobs] = value }
          parser.on("--duration-ms N", Integer, "Sleep or HTTP delay in ms") { |value| options[:payload][:duration_ms] = value }
          parser.on("--iterations N", Integer, "CPU workload iterations per job") { |value| options[:payload][:iterations] = value }
          parser.on("--timeout-s N", Integer, "Benchmark timeout in seconds") { |value| options[:timeout_s] = value }
          parser.on("--http-port N", Integer, "Local delay server port for HTTP workload") { |value| options[:http_port] = value }
          parser.on("--output-dir PATH", "Where to write JSON result files") { |value| options[:output_dir] = value }
        end.parse!(argv)

        normalize_payload!
      end

      def normalize_payload!
        case options[:workload]
        when "sleep", "http"
          options[:payload] = { duration_ms: options[:payload][:duration_ms] || 50 }
        when "cpu"
          options[:payload] = { iterations: options[:payload][:iterations] || 25_000 }
        else
          raise ArgumentError, "Unsupported workload: #{options[:workload]}"
        end
      end
  end
end
