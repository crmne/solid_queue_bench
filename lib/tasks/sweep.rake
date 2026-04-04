namespace :sweep do
  CAPACITIES = "10,25,50,75,100,150,200"
  PROCESSES  = "1,2,4"
  REPEAT     = ENV.fetch("REPEAT", "3")
  TIMEOUT    = ENV.fetch("TIMEOUT", "90")
  OUTPUT_DIR = "results"

  WORKLOADS = %w[sleep cpu llm_batch llm_stream http async_http]

  desc "Run all workload sweeps, generate charts, copy results"
  task all: :environment do
    WORKLOADS.each { |w| Rake::Task["sweep:#{w}"].invoke }
    Rake::Task["sweep:finalize"].invoke
  end

  desc "Sleep workload (2,000 jobs/cell)"
  task sleep: :environment do
    run_matrix(workload: "sleep", jobs: 2000, extra: "--duration-ms 50")
  end

  desc "CPU control workload (500 jobs/cell)"
  task cpu: :environment do
    run_matrix(workload: "cpu", jobs: 500, extra: "--iterations 50000")
  end

  desc "LLM batch workload -- 5s sleep (500 jobs/cell)"
  task llm_batch: :environment do
    run_matrix(workload: "llm_batch", jobs: 500, extra: "")
  end

  desc "LLM streaming workload -- parent + child broadcast jobs (200 jobs/cell)"
  task llm_stream: :environment do
    run_matrix(workload: "llm_stream", jobs: 200, extra: "")
  end

  desc "Net::HTTP workload (2,000 jobs/cell)"
  task http: :environment do
    run_matrix(workload: "http", jobs: 2000, extra: "--duration-ms 50")
  end

  desc "Async::HTTP workload (2,000 jobs/cell)"
  task async_http: :environment do
    run_matrix(workload: "async_http", jobs: 2000, extra: "--duration-ms 50")
  end

  desc "Copy latest results to results/ and regenerate charts"
  task finalize: :environment do
    require "fileutils"

    WORKLOADS.each do |workload|
      csv = latest_file("tmp/benchmarks", "sweep-#{workload}-*.csv")
      next unless csv

      base = workload.tr("_", "-")
      FileUtils.cp(csv, "results/#{base}-data.csv")

      json = csv.sub(".csv", ".json")
      FileUtils.cp(json, "results/#{base}-data.json") if File.exist?(json)

      puts "\nGenerating charts for #{workload}..."
      system("python3", "bin/plot", "results/#{base}-data.csv", "--output-dir", "results")

      %w[grid delta latency].each do |chart|
        src = "results/#{base}-data-#{chart}.png"
        dest_name = chart == "delta" ? "advantage" : chart
        dest = "results/#{base}-#{dest_name}.png"
        FileUtils.mv(src, dest) if File.exist?(src)
      end

      Dir.glob("results/#{base}-data-*.svg").each { |f| File.delete(f) }
    end

    puts "\n#{"=" * 60}"
    puts "All results in results/"
    system("ls", "-lh", "results/")
  end

  def run_matrix(workload:, jobs:, extra:)
    cmd = [
      "bin/matrix",
      "--workload", workload,
      "--jobs", jobs.to_s,
      "--capacities", CAPACITIES,
      "--processes", PROCESSES,
      "--repeat", REPEAT,
      "--timeout-s", TIMEOUT,
      "--output-dir", "tmp/benchmarks",
      "--name", "sweep",
      *extra.split.reject(&:empty?)
    ]

    puts "\n#{"=" * 60}"
    puts "Starting #{workload} sweep..."
    puts cmd.join(" ")
    puts "=" * 60

    system(*cmd) || warn("WARNING: #{workload} sweep exited with errors (some cells may have failed)")
  end

  def latest_file(dir, glob)
    Dir.glob(File.join(dir, glob)).max_by { |f| File.mtime(f) }
  end
end

desc "Run full benchmark suite (alias for sweep:all)"
task sweep: "sweep:all"
