namespace :sweep do
  HEADLINE_CAPACITIES = ENV.fetch("CAPACITIES", "5,10,25,50,100")
  STRESS_CAPACITIES = ENV.fetch("STRESS_CAPACITIES", "150,200")
  PRESSURE_CAPACITIES = ENV.fetch("PRESSURE_CAPACITIES", "25,50,100,150,200")
  HEADLINE_MAX_TOTAL_CONCURRENCY = ENV.fetch("HEADLINE_MAX_TOTAL_CONCURRENCY", "60")
  SOLID_QUEUE_PROCESSES = ENV.fetch("SOLID_QUEUE_PROCESSES", "1,2,6")
  ASYNC_JOB_PROCESSES = ENV.fetch("ASYNC_JOB_PROCESSES", "1,2,6")
  STRESS_SOLID_QUEUE_PROCESSES = ENV.fetch("STRESS_SOLID_QUEUE_PROCESSES", "2,6")
  REPEAT = ENV.fetch("REPEAT", "3")
  STRESS_REPEAT = ENV.fetch("STRESS_REPEAT", REPEAT)

  HEADLINE_WORKLOADS = %w[sleep cpu async_http ruby_llm_stream]
  STRESS_WORKLOADS = %w[sleep async_http ruby_llm_stream]
  SUPPLEMENTARY_WORKLOADS = %w[http llm_batch llm_stream]
  ALL_WORKLOADS = HEADLINE_WORKLOADS + SUPPLEMENTARY_WORKLOADS

  BACKEND_LABELS = {
    "solid_queue" => "solid-queue",
    "async_job" => "async-job",
    "solid_queue_stress" => "solid-queue-stress"
  }.freeze

  desc "Run the Solid Queue headline suite"
  task all: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, profile: :headline)
  end

  desc "Run the Solid Queue headline suite"
  task solid_queue_headline: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, profile: :headline)
  end

  desc "Run the Solid Queue full suite including supplementary workloads and stress capacities"
  task solid_queue_full: :environment do
    run_suite(backend: "solid_queue", workloads: ALL_WORKLOADS, profile: :full)
  end

  desc "Run the Async::Job headline suite"
  task async_job_headline: :environment do
    run_suite(backend: "async_job", workloads: HEADLINE_WORKLOADS, profile: :headline)
  end

  desc "Run the Async::Job full suite including supplementary workloads and stress capacities"
  task async_job_full: :environment do
    run_suite(backend: "async_job", workloads: ALL_WORKLOADS, profile: :full)
  end

  desc "Run both headline benchmark families"
  task families: :environment do
    run_suite(backend: "solid_queue", workloads: HEADLINE_WORKLOADS, profile: :headline)
    run_suite(backend: "async_job", workloads: HEADLINE_WORKLOADS, profile: :headline)
  end

  desc "Run every benchmark family, including supplementary workloads and stress capacities"
  task full: :environment do
    run_suite(backend: "solid_queue", workloads: ALL_WORKLOADS, profile: :full)
    run_suite(backend: "async_job", workloads: ALL_WORKLOADS, profile: :full)
  end

  desc "Run the Solid Queue supplementary synthetic/control suite"
  task supplementary: :environment do
    run_suite(backend: "solid_queue", workloads: SUPPLEMENTARY_WORKLOADS, profile: :headline)
  end

  desc "Run the Solid Queue stress suite focused on high-concurrency I/O and failure envelope"
  task solid_queue_stress: :environment do
    run_suite(backend: "solid_queue", workloads: STRESS_WORKLOADS, profile: :stress)
  end

  desc "Run only the Solid Queue sleep sweep"
  task sleep: :environment do
    run_workload(backend: "solid_queue", workload: "sleep", profile: :headline)
    finalize(backend: "solid_queue", workloads: [ "sleep" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Solid Queue cpu sweep"
  task cpu: :environment do
    run_workload(backend: "solid_queue", workload: "cpu", profile: :headline)
    finalize(backend: "solid_queue", workloads: [ "cpu" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Solid Queue async_http sweep"
  task async_http: :environment do
    run_workload(backend: "solid_queue", workload: "async_http", profile: :headline)
    finalize(backend: "solid_queue", workloads: [ "async_http" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Solid Queue ruby_llm_stream sweep"
  task ruby_llm_stream: :environment do
    run_workload(backend: "solid_queue", workload: "ruby_llm_stream", profile: :headline)
    finalize(backend: "solid_queue", workloads: [ "ruby_llm_stream" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Async::Job sleep sweep"
  task async_job_sleep: :environment do
    run_workload(backend: "async_job", workload: "sleep", profile: :headline)
    finalize(backend: "async_job", workloads: [ "sleep" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Async::Job cpu sweep"
  task async_job_cpu: :environment do
    run_workload(backend: "async_job", workload: "cpu", profile: :headline)
    finalize(backend: "async_job", workloads: [ "cpu" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Async::Job async_http sweep"
  task async_job_async_http: :environment do
    run_workload(backend: "async_job", workload: "async_http", profile: :headline)
    finalize(backend: "async_job", workloads: [ "async_http" ], prune_stale: false, profile: :headline)
  end

  desc "Run only the Async::Job ruby_llm_stream sweep"
  task async_job_ruby_llm_stream: :environment do
    run_workload(backend: "async_job", workload: "ruby_llm_stream", profile: :headline)
    finalize(backend: "async_job", workloads: [ "ruby_llm_stream" ], prune_stale: false, profile: :headline)
  end

  def run_suite(backend:, workloads:, profile:)
    workloads.each { |workload| run_workload(backend:, workload:, profile:) }
    finalize(backend:, workloads:, prune_stale: true, profile:)
  end

  def run_workload(backend:, workload:, profile:)
    prepare_database!
    spec = workload_spec(workload, profile:)
    capacities = capacities_for(backend:, profile:)

    run_matrix(
      backend:,
      workload:,
      jobs: spec.fetch(:jobs),
      timeout: spec.fetch(:timeout),
      extra: spec.fetch(:extra),
      capacities:,
      processes: processes_for(backend, profile:),
      repeat: repeat_for(profile:),
      output_dir: tmp_output_dir_for(backend, profile:),
      max_total_concurrency: max_total_concurrency_for(profile:)
    )
  end

  def workload_spec(workload, profile:)
    if profile == :stress
      case workload
      when "sleep"
        return {
          jobs: Integer(ENV.fetch("STRESS_SLEEP_JOBS", "500")),
          timeout: Integer(ENV.fetch("STRESS_SLEEP_TIMEOUT_S", "300")),
          extra: "--duration-ms #{ENV.fetch("STRESS_SLEEP_DURATION_MS", "250")}"
        }
      when "async_http"
        return {
          jobs: Integer(ENV.fetch("STRESS_ASYNC_HTTP_JOBS", "500")),
          timeout: Integer(ENV.fetch("STRESS_ASYNC_HTTP_TIMEOUT_S", "300")),
          extra: "--duration-ms #{ENV.fetch("STRESS_ASYNC_HTTP_DURATION_MS", "250")}"
        }
      when "ruby_llm_stream"
        return {
          jobs: Integer(ENV.fetch("STRESS_RUBY_LLM_STREAM_JOBS", "240")),
          timeout: Integer(ENV.fetch("STRESS_RUBY_LLM_STREAM_TIMEOUT_S", "600")),
          extra: "--token-count #{ENV.fetch("STRESS_RUBY_LLM_TOKEN_COUNT", "40")} --token-delay-ms #{ENV.fetch("STRESS_RUBY_LLM_TOKEN_DELAY_MS", "20")} --llm-model gpt-4.1-mini"
        }
      else
        raise ArgumentError, "Unknown stress workload: #{workload}"
      end
    end

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

  def run_matrix(backend:, workload:, jobs:, timeout:, extra:, capacities:, processes:, repeat:, output_dir:, max_total_concurrency: nil)
    cmd = [
      "bin/matrix",
      "--backend", backend,
      "--workload", workload,
      "--jobs", jobs.to_s,
      "--capacities", capacities,
      "--processes", processes,
      "--modes", modes_for(backend),
      "--repeat", repeat,
      "--timeout-s", timeout.to_s,
      "--output-dir", output_dir,
      "--name", "sweep",
      *extra.split.reject(&:empty?)
    ]
    cmd += [ "--max-total-concurrency", max_total_concurrency.to_s ] if max_total_concurrency

    puts "\n#{"=" * 60}"
    puts "Starting #{backend} #{workload} sweep..."
    puts cmd.join(" ")
    puts "=" * 60

    system(*cmd) || warn("WARNING: #{backend} #{workload} sweep exited with errors (some cells may have failed)")
  end

  def finalize(backend:, workloads:, prune_stale:, profile:)
    require "fileutils"

    destination_dir = results_dir_for(backend, profile:)
    FileUtils.mkdir_p(destination_dir)
    prune_stale_family_results!(destination_dir, keep_workloads: workloads) if prune_stale

    workloads.each do |workload|
      csv = latest_file(tmp_output_dir_for(backend, profile:), "sweep-#{backend_slug(backend)}-#{workload}-*.csv")
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

  def prune_stale_family_results!(destination_dir, keep_workloads:)
    keep_slugs = keep_workloads.map { |workload| workload.tr("_", "-") }
    stale_slugs = ALL_WORKLOADS.map { |workload| workload.tr("_", "-") } - keep_slugs

    stale_slugs.each do |slug|
      Dir.glob(File.join(destination_dir, "#{slug}-*")).each do |path|
        FileUtils.rm_f(path)
      end
    end
  end

  def backend_slug(backend)
    BACKEND_LABELS.fetch(backend)
  end

  def processes_for(backend, profile:)
    return STRESS_SOLID_QUEUE_PROCESSES if profile == :stress

    backend == "async_job" ? ASYNC_JOB_PROCESSES : SOLID_QUEUE_PROCESSES
  end

  def modes_for(backend)
    backend == "async_job" ? "async" : "thread,async"
  end

  def capacities_for(backend:, profile:)
    case profile
    when :headline
      HEADLINE_CAPACITIES
    when :full
      [ HEADLINE_CAPACITIES, STRESS_CAPACITIES ].join(",")
    when :stress
      raise ArgumentError, "stress suite is only supported for solid_queue" unless backend == "solid_queue"

      PRESSURE_CAPACITIES
    else
      raise ArgumentError, "Unknown profile: #{profile}"
    end
  end

  def repeat_for(profile:)
    profile == :stress ? STRESS_REPEAT : REPEAT
  end

  def max_total_concurrency_for(profile:)
    return if profile != :headline
    return if HEADLINE_MAX_TOTAL_CONCURRENCY.to_s.empty?

    HEADLINE_MAX_TOTAL_CONCURRENCY
  end

  def tmp_output_dir_for(backend, profile:)
    File.join("tmp/benchmarks", results_slug_for(backend, profile:))
  end

  def results_dir_for(backend, profile:)
    File.join("results", results_slug_for(backend, profile:))
  end

  def results_slug_for(backend, profile:)
    return backend_slug("solid_queue_stress") if profile == :stress

    backend_slug(backend)
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
