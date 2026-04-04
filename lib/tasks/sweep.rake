namespace :sweep do
  HEADLINE_CAPACITIES = ENV.fetch("CAPACITIES", "5,10,25,50,100")
  STRESS_CAPACITIES = ENV.fetch("STRESS_CAPACITIES", "150,200")
  SOLID_QUEUE_PROCESSES = ENV.fetch("SOLID_QUEUE_PROCESSES", "1,2,6")
  ASYNC_JOB_PROCESSES = ENV.fetch("ASYNC_JOB_PROCESSES", "1,2,6")
  REPEAT = ENV.fetch("REPEAT", "3")

  HEADLINE_WORKLOADS = %w[sleep cpu async_http ruby_llm_stream]
  SUPPLEMENTARY_WORKLOADS = %w[http llm_batch llm_stream]
  ALL_WORKLOADS = HEADLINE_WORKLOADS + SUPPLEMENTARY_WORKLOADS

  BACKEND_LABELS = {
    "solid_queue" => "solid-queue",
    "async_job" => "async-job"
  }.freeze

  desc "Run the Solid Queue headline suite"
  task all: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, include_stress: false)
  end

  desc "Run the Solid Queue headline suite"
  task solid_queue_headline: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, include_stress: false)
  end

  desc "Run the Solid Queue full suite including supplementary workloads and stress capacities"
  task solid_queue_full: :environment do
    run_suite(backend: "solid_queue", workloads: ALL_WORKLOADS, include_stress: true)
  end

  desc "Run the Async::Job headline suite"
  task async_job_headline: :environment do
    run_suite(backend: "async_job", workloads: HEADLINE_WORKLOADS, include_stress: false)
  end

  desc "Run the Async::Job full suite including supplementary workloads and stress capacities"
  task async_job_full: :environment do
    run_suite(backend: "async_job", workloads: ALL_WORKLOADS, include_stress: true)
  end

  desc "Run both headline benchmark families"
  task families: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, include_stress: false)
    run_suite(backend: "async_job", workloads: HEADLINE_WORKLOADS, include_stress: false)
  end

  desc "Run every benchmark family, including supplementary workloads and stress capacities"
  task full: :environment do
    run_suite(backend: "solid_queue", workloads: ALL_WORKLOADS, include_stress: true)
    run_suite(backend: "async_job", workloads: ALL_WORKLOADS, include_stress: true)
  end

  desc "Run the Solid Queue supplementary synthetic/control suite"
  task supplementary: :environment do
    run_suite(backend: "solid_queue", workloads: SUPPLEMENTARY_WORKLOADS, include_stress: false)
  end

  desc "Run only the Solid Queue sleep sweep"
  task sleep: :environment do
    run_workload(backend: "solid_queue", workload: "sleep", include_stress: false)
    finalize(backend: "solid_queue", workloads: [ "sleep" ])
  end

  desc "Run only the Solid Queue cpu sweep"
  task cpu: :environment do
    run_workload(backend: "solid_queue", workload: "cpu", include_stress: false)
    finalize(backend: "solid_queue", workloads: [ "cpu" ])
  end

  desc "Run only the Solid Queue async_http sweep"
  task async_http: :environment do
    run_workload(backend: "solid_queue", workload: "async_http", include_stress: false)
    finalize(backend: "solid_queue", workloads: [ "async_http" ])
  end

  desc "Run only the Solid Queue ruby_llm_stream sweep"
  task ruby_llm_stream: :environment do
    run_workload(backend: "solid_queue", workload: "ruby_llm_stream", include_stress: false)
    finalize(backend: "solid_queue", workloads: [ "ruby_llm_stream" ])
  end

  desc "Run only the Async::Job sleep sweep"
  task async_job_sleep: :environment do
    run_workload(backend: "async_job", workload: "sleep", include_stress: false)
    finalize(backend: "async_job", workloads: [ "sleep" ])
  end

  desc "Run only the Async::Job cpu sweep"
  task async_job_cpu: :environment do
    run_workload(backend: "async_job", workload: "cpu", include_stress: false)
    finalize(backend: "async_job", workloads: [ "cpu" ])
  end

  desc "Run only the Async::Job async_http sweep"
  task async_job_async_http: :environment do
    run_workload(backend: "async_job", workload: "async_http", include_stress: false)
    finalize(backend: "async_job", workloads: [ "async_http" ])
  end

  desc "Run only the Async::Job ruby_llm_stream sweep"
  task async_job_ruby_llm_stream: :environment do
    run_workload(backend: "async_job", workload: "ruby_llm_stream", include_stress: false)
    finalize(backend: "async_job", workloads: [ "ruby_llm_stream" ])
  end

  def run_suite(backend:, workloads:, include_stress:)
    workloads.each { |workload| run_workload(backend:, workload:, include_stress:) }
    finalize(backend:, workloads:)
  end

  def run_workload(backend:, workload:, include_stress:)
    prepare_database!
    spec = workload_spec(workload)
    capacities = include_stress ? [ HEADLINE_CAPACITIES, STRESS_CAPACITIES ].join(",") : HEADLINE_CAPACITIES

    run_matrix(
      backend:,
      workload:,
      jobs: spec.fetch(:jobs),
      timeout: spec.fetch(:timeout),
      extra: spec.fetch(:extra),
      capacities:
    )
  end

  def workload_spec(workload)
    case workload
    when "sleep"
      { jobs: 1000, timeout: 120, extra: "--duration-ms 50" }
    when "cpu"
      { jobs: 500, timeout: 90, extra: "--iterations 50000" }
    when "http"
      { jobs: 1000, timeout: 120, extra: "--duration-ms 50" }
    when "async_http"
      { jobs: 1000, timeout: 120, extra: "--duration-ms 50" }
    when "llm_batch"
      { jobs: 50, timeout: 600, extra: "--duration-s 5" }
    when "llm_stream"
      { jobs: 20, timeout: 240, extra: "--token-count 40 --token-delay-ms 20" }
    when "ruby_llm_stream"
      { jobs: 20, timeout: 240, extra: "--token-count 40 --token-delay-ms 20 --llm-model gpt-4.1-mini" }
    else
      raise ArgumentError, "Unknown workload: #{workload}"
    end
  end

  def run_matrix(backend:, workload:, jobs:, timeout:, extra:, capacities:)
    cmd = [
      "bin/matrix",
      "--backend", backend,
      "--workload", workload,
      "--jobs", jobs.to_s,
      "--capacities", capacities,
      "--processes", processes_for(backend),
      "--modes", modes_for(backend),
      "--repeat", REPEAT,
      "--timeout-s", timeout.to_s,
      "--output-dir", tmp_output_dir_for(backend),
      "--name", "sweep",
      *extra.split.reject(&:empty?)
    ]

    puts "\n#{"=" * 60}"
    puts "Starting #{backend} #{workload} sweep..."
    puts cmd.join(" ")
    puts "=" * 60

    system(*cmd) || warn("WARNING: #{backend} #{workload} sweep exited with errors (some cells may have failed)")
  end

  def finalize(backend:, workloads:)
    require "fileutils"

    destination_dir = results_dir_for(backend)
    FileUtils.mkdir_p(destination_dir)

    workloads.each do |workload|
      csv = latest_file(tmp_output_dir_for(backend), "sweep-#{backend_slug(backend)}-#{workload}-*.csv")
      next unless csv

      base = workload.tr("_", "-")
      FileUtils.cp(csv, File.join(destination_dir, "#{base}-data.csv"))

      json = csv.sub(".csv", ".json")
      FileUtils.cp(json, File.join(destination_dir, "#{base}-data.json")) if File.exist?(json)

      puts "\nGenerating charts for #{backend} #{workload}..."
      system("python3", "bin/plot", File.join(destination_dir, "#{base}-data.csv"), "--output-dir", destination_dir)

      %w[grid delta latency].each do |chart|
        src = File.join(destination_dir, "#{base}-data-#{chart}.png")
        dest_name = chart == "delta" ? "advantage" : chart
        dest = File.join(destination_dir, "#{base}-#{dest_name}.png")
        FileUtils.mv(src, dest) if File.exist?(src)
      end

      Dir.glob(File.join(destination_dir, "#{base}-data-*.svg")).each { |file| File.delete(file) }
    end

    system("ruby", "bin/report")
    puts "\n#{"=" * 60}"
    puts "#{backend} results in #{destination_dir}"
    system("ls", "-lh", destination_dir)
  end

  def backend_slug(backend)
    BACKEND_LABELS.fetch(backend)
  end

  def processes_for(backend)
    backend == "async_job" ? ASYNC_JOB_PROCESSES : SOLID_QUEUE_PROCESSES
  end

  def modes_for(backend)
    backend == "async_job" ? "async" : "thread,async"
  end

  def tmp_output_dir_for(backend)
    File.join("tmp/benchmarks", backend_slug(backend))
  end

  def results_dir_for(backend)
    File.join("results", backend_slug(backend))
  end

  def latest_file(dir, glob)
    Dir.glob(File.join(dir, glob)).max_by { |file| File.mtime(file) }
  end

  def prepare_database!
    system("bin/rails", "db:prepare") || raise("db:prepare failed")
    system(
      "bin/rails",
      "runner",
      "unless ActiveRecord::Base.connection.table_exists?(\"solid_queue_jobs\"); load Rails.root.join(\"db/queue_schema.rb\"); end"
    ) || raise("solid queue schema setup failed")

    [ BenchmarkRun, BenchmarkExecution ].each(&:reset_column_information)
    Chat.reset_column_information if defined?(Chat)
  end
end

desc "Run headline benchmark suite (alias for sweep:all)"
task sweep: "sweep:all"
