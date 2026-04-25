require "csv"
require "fileutils"
require "json"
require "pathname"
require "shellwords"
require "time"

module Bench
  class Report
    BACKENDS = {
      "solid-queue" => "Solid Queue",
      "async-job" => "Async::Job",
      "solid-queue-stress" => "Solid Queue Stress"
    }.freeze
    PROCESS_LABELS = [ "1 proc", "2 proc", "6 proc" ].freeze

    WORKLOADS = {
      "sleep" => "Sleep",
      "cpu" => "CPU",
      "http" => "Net::HTTP",
      "async_http" => "Async::HTTP",
      "db_queries" => "DB Queries",
      "db_transaction" => "DB Transaction",
      "db_transaction_pool_pressure" => "DB Transaction Pool Pressure",
      "db_mixed" => "DB Mixed",
      "llm_batch" => "LLM Batch",
      "llm_stream" => "LLM Stream",
      "ruby_llm_stream" => "RubyLLM Stream"
    }.freeze

    HEADLINE_WORKLOADS = %w[sleep async_http ruby_llm_stream cpu].freeze
    CONTROL_WORKLOADS = %w[http].freeze
    DB_WORKLOADS = %w[db_queries db_mixed db_transaction].freeze
    DB_PRESSURE_WORKLOADS = %w[db_transaction_pool_pressure].freeze
    SUPPLEMENTARY_WORKLOADS = CONTROL_WORKLOADS + DB_WORKLOADS
    PUBLIC_SOLID_QUEUE_WORKLOADS = HEADLINE_WORKLOADS + SUPPLEMENTARY_WORKLOADS
    STRESS_WORKLOADS = %w[sleep async_http ruby_llm_stream].freeze

    FAMILY_SUMMARIES = {
      "solid-queue" => "Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison.",
      "async-job" => "Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.",
      "solid-queue-stress" => "Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells."
    }.freeze

    VEGA_SCHEMA = "https://vega.github.io/schema/vega-lite/v6.json"
    METRIC_ORDER = [ "Throughput", "Peak RSS", "Avg CPU", "p50 latency" ].freeze
    LATENCY_PERCENTILES = %w[p50 p95 p99 max].freeze

    def initialize(results_root = File.expand_path("../../results", __dir__))
      @results_root = File.expand_path(results_root)
      @charts_dir = File.join(@results_root, "charts")
    end

    def self.call(...)
      new(...).call
    end

    def call
      FileUtils.mkdir_p(@charts_dir)
      datasets_by_family.each do |family, datasets|
        datasets.each { |dataset| write_workload_charts(dataset) }
        write_family_readme(family, datasets)
      end
      headline_charts = write_headline_charts
      stress_charts = write_stress_charts
      narrative = write_narrative
      write_root_readme(headline_charts:, stress_charts:, narrative:)
      write_project_readme(headline_charts:, stress_charts:, narrative:)
    end

    private

    Dataset = Struct.new(:family, :json_path, :data, keyword_init: true) do
      def workload
        data.fetch("workload")
      end

      def slug
        workload.tr("_", "-")
      end

      def csv_path
        json_path.sub(/\.json\z/, ".csv")
      end

      def rows
        data.fetch("results")
      end

      def successful_rows
        rows.select { |row| row["successful_jobs"].to_i.positive? }
      end

      def generated_at
        data["generated_at"]
      end

      def payload
        data["payload"] || {}
      end

      def repeat
        data["repeat"]
      end

      def db_pool
        data["db_pool"]
      end

      def planned_cells
        data["planned_cells"] || rows.size
      end

      def completed_cells
        rows.size
      end
    end

    def datasets_by_family
      BACKENDS.keys.to_h do |family|
        dir = File.join(@results_root, family)
        datasets = Dir.glob(File.join(dir, "*-data.json")).sort.filter_map do |path|
          data = JSON.parse(File.read(path))
          next unless data["results"].is_a?(Array)

          data["workload"] ||= File.basename(path, "-data.json").tr("-", "_")
          Dataset.new(family:, json_path: path, data:)
        end
        [ family, datasets ]
      end
    end

    def label_for_workload(workload)
      WORKLOADS.fetch(workload, workload.tr("_", " ").split.map(&:capitalize).join(" "))
    end

    def label_for_family(family)
      BACKENDS.fetch(family, family)
    end

    def dataset_summary(dataset)
      rows = dataset.successful_rows
      {
        tests: "#{dataset.completed_cells}/#{dataset.planned_cells}",
        best_throughput: rows.max_by { |row| number(row["jobs_per_second"]) || -Float::INFINITY },
        best_fiber_throughput: rows.select { |row| row["mode"] == "fiber" }.max_by { |row| number(row["jobs_per_second"]) || -Float::INFINITY },
        lowest_rss: rows.min_by { |row| number(row["peak_rss_kb"]) || Float::INFINITY },
        lowest_cpu: rows.min_by { |row| number(row["avg_cpu_pct"]) || Float::INFINITY },
        lowest_latency: rows.min_by { |row| number(row.dig("total_latency_ms", "p50")) || Float::INFINITY },
        throughput_win_rate: win_rate(rows, "jobs_per_second"),
        average_throughput_delta: average_delta(rows, "jobs_per_second"),
        throughput_delta: best_delta(rows, "jobs_per_second"),
        rss_delta: best_delta(rows, "peak_rss_kb", lower_is_better: true),
        cpu_delta: best_delta(rows, "avg_cpu_pct", lower_is_better: true),
        latency_delta: best_delta(rows, "total_latency_p50_ms", lower_is_better: true)
      }
    end

    def best_delta(rows, metric, lower_is_better: false)
      deltas = paired_rows(rows).filter_map do |thread, fiber|
        thread_value = metric_value(thread, metric)
        fiber_value = metric_value(fiber, metric)
        next unless thread_value&.positive? && fiber_value

        raw = ((fiber_value - thread_value) / thread_value) * 100.0
        raw *= -1 if lower_is_better
        {
          value: raw,
          concurrency: thread["concurrency"],
          processes: thread["processes"],
          thread:,
          fiber:
        }
      end
      deltas.max_by { |delta| delta[:value] }
    end

    def average_delta(rows, metric, lower_is_better: false)
      values = paired_rows(rows).filter_map do |thread, fiber|
        thread_value = metric_value(thread, metric)
        fiber_value = metric_value(fiber, metric)
        next unless thread_value&.positive? && fiber_value

        value = ((fiber_value - thread_value) / thread_value) * 100.0
        lower_is_better ? -value : value
      end
      return unless values.any?

      { value: values.sum / values.size, pairs: values.size }
    end

    def win_rate(rows, metric)
      pairs = paired_rows(rows)
      wins = pairs.count do |thread, fiber|
        thread_value = metric_value(thread, metric)
        fiber_value = metric_value(fiber, metric)
        thread_value && fiber_value && fiber_value > thread_value
      end
      { wins:, pairs: pairs.size }
    end

    def paired_rows(rows)
      rows.group_by { |row| [ row["concurrency"], row["processes"] ] }.filter_map do |_cell, grouped|
        thread = grouped.find { |row| row["mode"] == "thread" }
        fiber = grouped.find { |row| row["mode"] == "fiber" }
        [ thread, fiber ] if thread && fiber
      end
    end

    def metric_value(row, metric)
      case metric
      when "total_latency_p50_ms"
        number(row.dig("total_latency_ms", "p50"))
      else
        number(row[metric])
      end
    end

    def number(value)
      value if value.is_a?(Numeric)
    end

    def fmt_number(value, digits = 2)
      return "n/a" unless value.is_a?(Numeric)

      format("%.#{digits}f", value)
    end

    def fmt_percent(value)
      return "n/a" unless value.is_a?(Numeric)

      format("%+.1f%%", value)
    end

    def fmt_cell(row, metric, scale: 1.0, unit: nil)
      return "n/a" unless row

      value = metric_value(row, metric)
      rendered = fmt_number(value ? value * scale : nil)
      rendered = "#{rendered}#{unit}" if unit
      [ row["mode"], "c=#{row["concurrency"]}", "proc=#{row["processes"]}", rendered ].join(", ")
    end

    def relative_link(from_dir, target_path, label)
      relative = Pathname.new(target_path).relative_path_from(Pathname.new(from_dir)).to_s
      "[#{label}](#{relative})"
    end

    def solid_queue_revision(datasets = nil)
      explicit = ENV["SOLID_QUEUE_REVISION"].to_s.strip
      return explicit unless explicit.empty?

      revisions = Array(datasets).filter_map { |dataset| dataset.data["solid_queue_revision"] }.uniq
      return revisions.first if revisions.one?
      return revisions.join(", ") if revisions.size > 1

      repo = File.expand_path("../../../solid_queue", __dir__)
      return unless Dir.exist?(repo)

      sha = `git -C #{Shellwords.escape(repo)} rev-parse HEAD 2>/dev/null`.strip
      sha.empty? ? nil : sha
    end

    def write_family_readme(family, datasets)
      dir = File.join(@results_root, family)
      lines = []
      lines << "# #{label_for_family(family)} Results"
      lines << ""
      lines << "Auto-generated from the benchmark artifacts in this directory."
      lines << ""

      if datasets.empty?
        lines << "No result datasets found."
        File.write(File.join(dir, "README.md"), lines.join("\n") + "\n")
        return
      end

      lines << "Latest dataset timestamp: `#{datasets.filter_map(&:generated_at).max}`"
      revision = solid_queue_revision(datasets)
      lines << "Solid Queue commit under test: `#{revision}`" if family.start_with?("solid-queue") && revision
      lines << ""
      lines << FAMILY_SUMMARIES.fetch(family)
      lines << ""
      lines << "| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |"
      lines << "|---|---|---|---|---|---|---|---|"

      datasets.sort_by { |dataset| workload_sort_key(dataset.workload) }.each do |dataset|
        summary = dataset_summary(dataset)
        delta = summary[:throughput_delta]
        delta_text = delta ? "#{fmt_percent(delta[:value])} at c=#{delta[:concurrency]}, proc=#{delta[:processes]}" : "n/a"
        average_delta = summary[:average_throughput_delta]
        average_delta_text = average_delta ? "#{fmt_percent(average_delta[:value])} across #{average_delta[:pairs]} cells" : "n/a"
        artifacts = [
          relative_link(dir, dataset.csv_path, "CSV"),
          relative_link(dir, dataset.json_path, "JSON")
        ] + chart_links(dir, dataset)

        lines << "| #{label_for_workload(dataset.workload)} | #{summary[:tests]} | #{fmt_cell(summary[:best_throughput], "jobs_per_second", unit: " jobs/s")} | #{fmt_cell(summary[:lowest_rss], "peak_rss_kb", scale: 1.0 / 1024.0, unit: " MB")} | #{fmt_cell(summary[:lowest_latency], "total_latency_p50_ms", unit: " ms")} | #{average_delta_text} | #{delta_text} | #{artifacts.join(' / ')} |"
      end

      lines << ""
      lines << "## Notes"
      lines << ""
      lines << "- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell."
      lines << "- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas."
      lines << "- `Tests` is `completed/planned`, so failed or timed-out cells stay visible."
      lines << "- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there."

      File.write(File.join(dir, "README.md"), lines.join("\n") + "\n")
    end

    def chart_links(dir, dataset)
      %w[grid advantage latency].filter_map do |kind|
        json = File.join(@charts_dir, "#{dataset.family}-#{dataset.slug}-#{kind}.vg.json")
        next unless File.exist?(json)

        svg = json.sub(/\.vg\.json\z/, ".svg")
        path = File.exist?(svg) ? svg : json
        relative_link(dir, path, kind.capitalize)
      end
    end

    def workload_sort_key(workload)
      order = PUBLIC_SOLID_QUEUE_WORKLOADS + DB_PRESSURE_WORKLOADS
      [ order.index(workload) || order.length, workload ]
    end

    def write_root_readme(headline_charts:, stress_charts:, narrative:)
      lines = []
      family_dirs = datasets_by_family.select { |_family, datasets| datasets.any? }.keys
      lines << "# Benchmark Results"
      lines << ""
      lines << "Benchmark outputs live in the per-family directories below. The generated narrative is in #{relative_link(@results_root, narrative, 'narrative.md')}."
      lines << ""
      revision = solid_queue_revision(datasets_by_family.values.flatten)
      lines << "Solid Queue commit under test: `#{revision}`" if revision
      lines << ""
      lines << "| Family | What It Shows | Summary |"
      lines << "|---|---|---|"
      family_dirs.each do |family|
        dir = File.join(@results_root, family)
        lines << "| #{label_for_family(family)} | #{FAMILY_SUMMARIES.fetch(family)} | #{relative_link(@results_root, File.join(dir, 'README.md'), 'README')} |"
      end
      lines << ""
      lines << "## Headline Charts"
      lines << ""
      lines.concat(chart_list(@results_root, headline_charts))
      lines << ""
      lines << "## Stress Charts"
      lines << ""
      lines.concat(chart_list(@results_root, stress_charts))

      File.write(File.join(@results_root, "README.md"), lines.join("\n") + "\n")
    end

    def write_project_readme(headline_charts:, stress_charts:, narrative:)
      return unless project_root

      prompt_path = File.expand_path("readme_prompt.md", __dir__)
      facts = public_report_facts(headline_charts:, stress_charts:, narrative:)
      readme = generate_markdown(prompt_path, facts) || deterministic_project_readme(facts)
      readme = readme.sub(/\A<!--.*?-->\s*/m, "")
      File.write(File.join(project_root, "README.md"), generated_file_header + readme.strip + "\n")
    end

    def public_report_facts(headline_charts:, stress_charts:, narrative:)
      datasets = datasets_by_family
      all_datasets = datasets.values.flatten
      public_results = filtered_report_facts(
        "solid-queue" => PUBLIC_SOLID_QUEUE_WORKLOADS,
        "async-job" => HEADLINE_WORKLOADS,
        "solid-queue-stress" => STRESS_WORKLOADS
      )

      {
        title: "Solid Queue Bench",
        audience: "Rails developers deciding whether to use Solid Queue fiber execution mode.",
        source_note: "Generated by bin/report from checked-in results JSON and CSV artifacts.",
        result_dates: result_date_range(all_datasets),
        solid_queue_revision: solid_queue_revision(all_datasets),
        research_questions: research_questions,
        methodology: methodology_notes,
        benchmark_matrix: benchmark_matrix_facts(all_datasets),
        workloads: public_workload_descriptions,
        results: public_results,
        public_scope: {
          headline_workloads: HEADLINE_WORKLOADS,
          supplementary_workloads: SUPPLEMENTARY_WORKLOADS,
          db_workloads: DB_WORKLOADS,
          omitted_workloads: DB_PRESSURE_WORKLOADS,
          stress_interpretation: "Treat stress as a current Solid Queue failure-envelope test driven by implementation choices around high-concurrency connection demand, not as an intrinsic thread-vs-fiber law."
        },
        stress_completion: stress_completion_facts(datasets.fetch("solid-queue-stress", [])),
        charts: {
          headline: chart_facts(headline_charts),
          db: workload_chart_facts("solid-queue", DB_WORKLOADS, "advantage"),
          stress: chart_facts(stress_charts)
        },
        links: {
          generated_artifacts: "results/README.md",
          narrative: relative_path(project_root, narrative),
          solid_queue_results: "results/solid-queue/README.md",
          async_job_results: "results/async-job/README.md",
          stress_results: "results/solid-queue-stress/README.md"
        },
        setup: setup_facts,
        running: running_facts,
        caveats: caveats
      }
    end

    def deterministic_project_readme(facts)
      lines = []
      lines << "# Solid Queue Bench"
      lines << ""
      lines << "Benchmark harness for answering whether Solid Queue `fiber` execution mode is faster, cheaper, or easier on the database than `thread` mode under the same Rails app and backend."
      lines << ""
      lines << "In this repo, `concurrency = N` means Solid Queue runs `threads: N` in thread mode or `fibers: N` in fiber mode. `Processes` is the number of worker OS processes, so total execution slots are `concurrency x processes`."
      lines << ""
      lines << "Latest checked-in results: **#{facts[:result_dates]}**."
      lines << "Solid Queue commit under test: `#{facts[:solid_queue_revision]}`." if facts[:solid_queue_revision]
      lines << ""
      lines << "Full generated artifacts: [results](#{facts[:links][:generated_artifacts]}), [Solid Queue](#{facts[:links][:solid_queue_results]}), [Async::Job](#{facts[:links][:async_job_results]}), and [stress](#{facts[:links][:stress_results]})."
      lines << ""
      lines << "## Research Questions"
      lines << ""
      facts[:research_questions].each { |question| lines << "- #{question}" }
      lines << ""
      lines << "## Headline Results"
      lines << ""
      lines << "Inside Solid Queue, this is a same-backend comparison on the headline workloads: the queue, Rails app, jobs, and matrix are the same; only the worker execution mode changes."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:headline]))
      lines << ""
      lines.concat(workload_summary_table(facts, "solid-queue", workloads: HEADLINE_WORKLOADS))
      lines << ""
      lines << "The strongest fiber gains show up where the jobs spend meaningful time waiting. CPU remains close, which is the expected control. The DB and blocking-HTTP workloads are reported separately below so the headline section stays aligned with the headline charts."
      lines << ""
      lines << "Full supplementary Solid Queue results, including `http`, `db_queries`, `db_mixed`, and `db_transaction`, are in [results/solid-queue/README.md](#{facts[:links][:solid_queue_results]})."
      lines << ""
      lines << "## DB Workloads"
      lines << ""
      lines << "| Workload | What It Tests | Payload | DB Pool | Avg Fiber Throughput Delta | Best Fiber Throughput Delta |"
      lines << "|---|---|---|---|---:|---:|"
      db_result_rows(facts).each { |row| lines << row }
      lines << ""
      lines << "`DB Transaction` uses a matched pool (`concurrency + 5` per process for both modes), so it is the fair executor comparison. The public README intentionally excludes the old default-pool transaction pressure variant because it is not an apples-to-apples executor comparison."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:db]))
      lines << ""
      lines << "## Stress Suite"
      lines << ""
      lines << "The headline suite caps total concurrency at `60` to keep the mode comparison fair. The stress suite removes that cap and is best read as a current Solid Queue failure-envelope test under high connection demand."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:stress]))
      lines << ""
      lines << "| Workload | Fiber Cells | Thread Cells |"
      lines << "|---|---:|---:|"
      facts[:stress_completion].each do |row|
        lines << "| #{row[:label]} | #{row.dig(:modes, "fiber", :completed)}/#{row.dig(:modes, "fiber", :planned)} | #{row.dig(:modes, "thread", :completed)}/#{row.dig(:modes, "thread", :planned)} |"
      end
      lines << ""
      lines << "These stress results reflect the current Solid Queue implementation and its connection-pool sizing behavior at high thread counts. They should not be read as a permanent or fundamental property of threads."
      lines << ""
      lines << "## Async::Job Comparison"
      lines << ""
      lines << "Async::Job + Redis is a different backend, so it is not evidence about Solid Queue `thread` vs `fiber`. It is useful as a throughput-ceiling reference for the same ActiveJob-shaped workloads."
      lines << ""
      lines.concat(async_job_table(facts))
      lines << ""
      lines << "## Methodology"
      lines << ""
      facts[:methodology].each { |note| lines << "- #{note}" }
      lines << ""
      lines << "## Workloads"
      lines << ""
      lines << "| Workload | Shape | Purpose |"
      lines << "|---|---|---|"
      facts[:workloads].each do |workload|
        lines << "| `#{workload[:name]}` | #{workload[:shape]} | #{workload[:purpose]} |"
      end
      lines << ""
      lines << "## Setup"
      lines << ""
      lines << "Requirements: Ruby 4.0+, PostgreSQL, Redis (Docker or local on `127.0.0.1:6379`). The Async::Job path auto-starts a `redis:7-alpine` container when Docker is available and Redis is not reachable."
      lines << ""
      lines << "The Gemfile expects a local Solid Queue checkout:"
      lines << ""
      lines << "```ruby"
      lines << 'gem "solid_queue", path: "../solid_queue"'
      lines << "```"
      lines << ""
      lines << "```bash"
      lines << "export DB_USER=your_user"
      lines << "export DB_PASSWORD=your_password"
      lines << "source .env"
      lines << ""
      lines << "bin/setup"
      lines << "```"
      lines << ""
      lines << "`bin/setup` installs gems, prepares the database, ensures the Solid Queue schema exists, and loads the RubyLLM model catalog. `.env` is a shell-friendly `OPENAI_API_KEY` export; source it or set `OPENAI_API_KEY` another way."
      lines << ""
      lines << "## Running"
      lines << ""
      lines << "```bash"
      facts[:running][:sweep_tasks].each { |task| lines << task }
      lines << "```"
      lines << ""
      lines << "Single-workload sweeps are available too, including `sweep:sleep`, `sweep:db_queries`, `sweep:db_transaction`, `sweep:db_mixed`, `sweep:ruby_llm_stream`, and the `sweep:async_job_*` tasks."
      lines << ""
      lines << "Regenerate the public README, result summaries, charts, and narrative from existing artifacts:"
      lines << ""
      lines << "```bash"
      lines << "bin/report"
      lines << "```"
      lines << ""
      lines << "When `OPENAI_API_KEY` is set, `bin/report` asks RubyLLM to write the public README and narrative from the benchmark facts. Without it, the same command uses the deterministic fallback so tables and charts still update."
      lines << ""
      lines << "## Caveats"
      lines << ""
      facts[:caveats].each { |caveat| lines << "- #{caveat}" }
      lines.join("\n")
    end

    def chart_list(from_dir, paths)
      paths.map do |path|
        label = File.basename(path).sub(/\.vg\.json\z/, "").sub(/\.svg\z/, "").tr("-", " ").split.map(&:capitalize).join(" ")
        "- #{relative_link(from_dir, preferred_chart_path(path), label)}"
      end
    end

    def preferred_chart_path(path)
      svg = path.sub(/\.vg\.json\z/, ".svg")
      File.exist?(svg) ? svg : path
    end

    def project_root
      return @project_root if defined?(@project_root)

      @project_root = File.basename(@results_root) == "results" ? File.expand_path("..", @results_root) : nil
    end

    def generated_file_header
      "<!-- Generated by bin/report from results/*.json. Edit lib/bench/report.rb or lib/bench/readme_prompt.md, not this file. -->\n\n"
    end

    def relative_path(from_dir, target_path)
      return unless from_dir && target_path

      Pathname.new(target_path).relative_path_from(Pathname.new(from_dir)).to_s
    end

    def result_date_range(datasets)
      times = datasets.filter_map do |dataset|
        Time.parse(dataset.generated_at.to_s)
      rescue ArgumentError, TypeError
        nil
      end.sort
      return "unknown" if times.empty?

      first = times.first.utc
      last = times.last.utc
      return first.strftime("%B %-d, %Y") if first.strftime("%Y%m%d") == last.strftime("%Y%m%d")
      return "#{first.strftime("%B %-d")}-#{last.strftime("%-d, %Y")}" if first.year == last.year && first.month == last.month

      "#{first.strftime("%B %-d, %Y")} to #{last.strftime("%B %-d, %Y")}"
    end

    def research_questions
      [
        "Is Solid Queue `fiber` faster than Solid Queue `thread` for the same workload?",
        "Does `fiber` reduce memory, CPU, latency, or database connection pressure?",
        "Do short DB bursts still work well with a smaller shared fiber pool?",
        "What happens when jobs pin database connections for a whole transaction?",
        "How much faster is Async::Job + Redis when the backend changes too?"
      ]
    end

    def methodology_notes
      [
        "Timing starts after workers are ready.",
        "`jobs_per_second` counts successful jobs only.",
        "Latency percentiles are from successful jobs only.",
        "Each matrix cell is repeated and reports a real representative run, not a synthetic average row.",
        "In Solid Queue, `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode. `Processes` is the number of worker OS processes.",
        "The headline suite is limited to `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.",
        "Supplementary Solid Queue runs add `http`, `db_queries`, `db_mixed`, and `db_transaction`.",
        "The headline and supplementary suites cap total concurrency at `60` so high process counts do not turn the main comparison into a pool-exhaustion test.",
        "Cells above that cap are intentionally omitted from the capped suites, so higher concurrencies may show only `1 proc` results.",
        "The stress suite removes that cap and is best read as a current Solid Queue failure-envelope test, not as a fundamental thread-vs-fiber law.",
        "Streaming workloads are child-job aware: a run is not complete until downstream broadcast jobs finish."
      ]
    end

    def workload_descriptions
      [
        { name: "sleep", shape: "`Kernel.sleep`", purpose: "Cooperative wait upper bound" },
        { name: "async_http", shape: "Local `Async::HTTP` call", purpose: "Fiber-friendly I/O" },
        { name: "ruby_llm_stream", shape: "Fake OpenAI SSE + RubyLLM chat + Turbo broadcasts", purpose: "Production-shaped streaming" },
        { name: "cpu", shape: "SHA256 loop", purpose: "CPU-bound control" },
        { name: "http", shape: "Local `Net::HTTP` call", purpose: "Blocking HTTP control" },
        { name: "db_queries", shape: "Sequential DB reads plus writes", purpose: "Report generation / data sync without external I/O" },
        { name: "db_mixed", shape: "DB reads, delayed HTTP call, then DB writes", purpose: "Read state, call API, write result" },
        { name: "db_transaction", shape: "DB reads and writes in one transaction", purpose: "Fair transaction executor comparison with matched pools" },
        { name: "db_transaction_pool_pressure", shape: "Same transaction under mode-specific default pools", purpose: "Exploratory current-default pool-pressure test" }
      ]
    end

    def public_workload_descriptions
      workload_descriptions.reject { |workload| DB_PRESSURE_WORKLOADS.include?(workload[:name]) }
    end

    def benchmark_matrix_facts(datasets)
      families = {}

      headline_dataset = datasets.find { |dataset| dataset.family == "solid-queue" && HEADLINE_WORKLOADS.include?(dataset.workload) }
      if headline_dataset
        families["solid_queue_headline"] = {
          label: "Solid Queue headline",
          workloads: HEADLINE_WORKLOADS,
          concurrencies: headline_dataset.data["concurrencies"],
          processes: headline_dataset.data["processes"],
          modes: headline_dataset.data["modes"],
          repeat: headline_dataset.repeat,
          max_total_concurrency: headline_dataset.data["max_total_concurrency"]
        }
      end

      supplementary_dataset = datasets.find { |dataset| dataset.family == "solid-queue" && SUPPLEMENTARY_WORKLOADS.include?(dataset.workload) }
      if supplementary_dataset
        families["solid_queue_supplementary"] = {
          label: "Solid Queue supplementary",
          workloads: SUPPLEMENTARY_WORKLOADS,
          concurrencies: supplementary_dataset.data["concurrencies"],
          processes: supplementary_dataset.data["processes"],
          modes: supplementary_dataset.data["modes"],
          repeat: supplementary_dataset.repeat,
          max_total_concurrency: supplementary_dataset.data["max_total_concurrency"]
        }
      end

      async_dataset = datasets.find { |dataset| dataset.family == "async-job" && HEADLINE_WORKLOADS.include?(dataset.workload) }
      if async_dataset
        families["async_job_headline"] = {
          label: "Async::Job headline",
          workloads: HEADLINE_WORKLOADS,
          concurrencies: async_dataset.data["concurrencies"],
          processes: async_dataset.data["processes"],
          modes: async_dataset.data["modes"],
          repeat: async_dataset.repeat,
          max_total_concurrency: async_dataset.data["max_total_concurrency"]
        }
      end

      stress_dataset = datasets.find { |dataset| dataset.family == "solid-queue-stress" }
      if stress_dataset
        families["solid_queue_stress"] = {
          label: "Solid Queue stress",
          workloads: STRESS_WORKLOADS,
          concurrencies: stress_dataset.data["concurrencies"],
          processes: stress_dataset.data["processes"],
          modes: stress_dataset.data["modes"],
          repeat: stress_dataset.repeat,
          max_total_concurrency: stress_dataset.data["max_total_concurrency"]
        }
      end

      families
    end

    def filtered_report_facts(workloads_by_family)
      report_facts.each_with_object({}) do |(family, rows), filtered|
        allowed = Array(workloads_by_family[family])
        filtered[family] = rows.select { |row| allowed.include?(row[:workload]) }
      end
    end

    def stress_completion_facts(datasets)
      datasets.sort_by { |dataset| workload_sort_key(dataset.workload) }.map do |dataset|
        planned_per_mode = Array(dataset.data["concurrencies"]).size * Array(dataset.data["processes"]).size
        modes = Array(dataset.data["modes"]).to_h do |mode|
          completed = dataset.rows.count { |row| row["mode"] == mode }
          [ mode, { completed:, planned: planned_per_mode } ]
        end
        { workload: dataset.workload, label: label_for_workload(dataset.workload), modes: }
      end
    end

    def chart_facts(paths)
      paths.map do |path|
        preferred = preferred_chart_path(path)
        {
          label: chart_title(path),
          path: relative_path(project_root, preferred),
          embeddable: preferred.end_with?(".svg", ".png")
        }
      end
    end

    def workload_chart_facts(family, workloads, kind)
      paths = workloads.filter_map do |workload|
        path = File.join(@charts_dir, "#{family}-#{workload.tr("_", "-")}-#{kind}.vg.json")
        path if File.exist?(path)
      end
      chart_facts(paths)
    end

    def running_facts
      {
        sweep_tasks: [
          "bundle exec rake sweep:solid_queue_headline   # Headline Solid Queue",
          "bundle exec rake sweep:solid_queue_stress      # Stress suite",
          "bundle exec rake sweep:async_job_headline      # Headline Async::Job",
          "bundle exec rake sweep:families                # Both headline families",
          "bundle exec rake sweep:full                    # Headline + HTTP control + DB",
          "bundle exec rake sweep:publish                 # Public README/report suite"
        ]
      }
    end

    def setup_facts
      {
        requirements: [
          "Ruby 4.0+",
          "PostgreSQL",
          "Redis, either local on 127.0.0.1:6379 or auto-started through Docker for Async::Job"
        ],
        solid_queue_gem: 'gem "solid_queue", path: "../solid_queue"',
        commands: [
          "export DB_USER=your_user",
          "export DB_PASSWORD=your_password",
          "source .env",
          "bin/setup"
        ],
        notes: [
          "`bin/setup` installs gems, prepares the database, ensures the Solid Queue schema exists, and loads the RubyLLM model catalog.",
          "`.env` is a shell-friendly `OPENAI_API_KEY` export; source it or set `OPENAI_API_KEY` another way."
        ]
      }
    end

    def caveats
      [
        "The data shows best and lowest observed results from this tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.",
        "Async::Job changes the backend, so those numbers are a backend comparison rather than a Solid Queue mode comparison.",
        "`db_transaction` is the fair transaction comparison because the DB pool is matched for both modes.",
        "Stress results reflect the current Solid Queue implementation under high connection demand and should not be read as a permanent thread-vs-fiber law.",
        "The harness uses aggressive queue polling, so these numbers reflect execution behavior under a low-latency benchmark configuration, not default production settings."
      ]
    end

    def chart_embeds(charts)
      charts.flat_map do |chart|
        line = chart[:embeddable] ? "![#{chart[:label]}](#{chart[:path]})" : "[#{chart[:label]}](#{chart[:path]})"
        [ line, "" ]
      end.tap(&:pop)
    end

    def workload_summary_table(facts, family, workloads: nil)
      rows = facts[:results].fetch(family, [])
      rows = rows.select { |result| workloads.include?(result[:workload]) } if workloads
      rows = rows.sort_by { |result| workload_sort_key(result[:workload]) }
      lines = []
      lines << "| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta |"
      lines << "|---|---:|---|---|---|---:|---:|"
      rows.each do |result|
        lines << "| #{result[:label]} | #{result[:tests]} | #{summary_cell(result[:best_throughput], "jobs_per_second", unit: " jobs/s")} | #{summary_cell(result[:lowest_rss], "peak_rss_kb", scale: 1.0 / 1024.0, unit: " MB")} | #{summary_cell(result[:lowest_latency], "total_latency_p50_ms", unit: " ms")} | #{average_delta_text(result[:average_fiber_delta])} | #{delta_text(result[:best_fiber_delta])} |"
      end
      lines
    end

    def db_result_rows(facts)
      DB_WORKLOADS.filter_map do |workload|
        result = result_for(facts, "solid-queue", workload)
        next unless result

        description = workload_descriptions.find { |entry| entry[:name] == workload }
        db_pool = result[:db_pool] || "mode-specific"
        "| #{result[:label]} | #{description[:purpose]} | #{payload_text(result[:payload])} | #{db_pool} | #{average_delta_text(result[:average_fiber_delta])} | #{delta_text(result[:best_fiber_delta])} |"
      end
    end

    def async_job_table(facts)
      lines = []
      lines << "| Workload | Solid Queue Fiber Best | Async::Job Best | Async::Job Delta |"
      lines << "|---|---:|---:|---:|"
      HEADLINE_WORKLOADS.each do |workload|
        solid_queue = result_for(facts, "solid-queue", workload)
        async_job = result_for(facts, "async-job", workload)
        next unless solid_queue && async_job

        sq_value = solid_queue.dig(:best_fiber_throughput, "jobs_per_second")
        aj_value = async_job.dig(:best_throughput, "jobs_per_second")
        delta = sq_value&.positive? && aj_value ? ((aj_value - sq_value) / sq_value) * 100.0 : nil
        lines << "| #{solid_queue[:label]} | #{fmt_number(sq_value)} jobs/s | #{fmt_number(aj_value)} jobs/s | #{fmt_percent(delta)} |"
      end
      lines
    end

    def result_for(facts, family, workload)
      facts[:results].fetch(family, []).find { |result| result[:workload] == workload }
    end

    def payload_text(payload)
      return "n/a" unless payload && !payload.empty?

      payload.map { |key, value| "`#{key}=#{value}`" }.join(", ")
    end

    def summary_cell(row, metric, scale: 1.0, unit: nil)
      return "n/a" unless row

      value = case metric
      when "total_latency_p50_ms"
        row.dig("total_latency_ms", "p50")
      else
        row[metric]
      end
      rendered = fmt_number(value ? value * scale : nil)
      rendered = "#{rendered}#{unit}" if unit
      [ row["mode"], "c=#{row["concurrency"]}", "proc=#{row["processes"]}", rendered ].join(", ")
    end

    def delta_text(delta)
      return "n/a" unless delta

      "#{fmt_percent(delta[:value])} at c=#{delta[:concurrency]}, proc=#{delta[:processes]}"
    end

    def average_delta_text(delta)
      return "n/a" unless delta

      "#{fmt_percent(delta[:value])} across #{delta[:pairs]} cells"
    end

    def write_workload_charts(dataset)
      rows = dataset.successful_rows
      write_chart("#{dataset.family}-#{dataset.slug}-grid", workload_grid_spec(dataset, rows))
      write_chart("#{dataset.family}-#{dataset.slug}-advantage", workload_advantage_spec(dataset, rows)) if paired_rows(rows).any?
      write_chart("#{dataset.family}-#{dataset.slug}-latency", workload_latency_spec(dataset, rows))
    end

    def workload_grid_spec(dataset, rows)
      values = rows.flat_map do |row|
        [
          metric_row(row, "Throughput", metric_value(row, "jobs_per_second"), "jobs/s"),
          metric_row(row, "Peak RSS", metric_value(row, "peak_rss_kb").to_f / 1024.0, "MB"),
          metric_row(row, "Avg CPU", metric_value(row, "avg_cpu_pct"), "%"),
          metric_row(row, "p50 latency", metric_value(row, "total_latency_p50_ms"), "ms")
        ]
      end

      line_spec(
        title: "#{label_for_family(dataset.family)} #{label_for_workload(dataset.workload)}",
        values:,
        y_title: "Value",
        facet_row: "metric",
        facet_column: "processes",
        facet_row_sort: METRIC_ORDER,
        width: 180,
        height: 120
      )
    end

    def workload_latency_spec(dataset, rows)
      values = rows.flat_map do |row|
        LATENCY_PERCENTILES.map do |percentile|
          {
            mode: row["mode"],
            concurrency: row["concurrency"],
            processes: "#{row["processes"]} proc",
            percentile:,
            value: number(row.dig("total_latency_ms", percentile))
          }
        end
      end.compact

      line_spec(
        title: "#{label_for_family(dataset.family)} #{label_for_workload(dataset.workload)} Latency",
        values:,
        y_title: "Latency (ms)",
        color_field: "percentile",
        stroke_dash_field: "mode",
        facet_column: "processes",
        color_sort: LATENCY_PERCENTILES,
        width: 200,
        height: 220
      )
    end

    def workload_advantage_spec(dataset, rows)
      values = paired_rows(rows).flat_map do |thread, fiber|
        [
          advantage_row(thread, fiber, "Throughput", "jobs_per_second", lower_is_better: false),
          advantage_row(thread, fiber, "Peak RSS", "peak_rss_kb", lower_is_better: true),
          advantage_row(thread, fiber, "Avg CPU", "avg_cpu_pct", lower_is_better: true),
          advantage_row(thread, fiber, "p50 latency", "total_latency_p50_ms", lower_is_better: true)
        ]
      end.compact

      bar_spec(
        title: "#{label_for_family(dataset.family)} #{label_for_workload(dataset.workload)} Fiber Advantage",
        values:,
        y_title: "Fiber advantage (%)",
        facet_column: "metric",
        facet_column_sort: METRIC_ORDER,
        width: 180,
        height: 220
      )
    end

    def metric_row(row, metric, value, unit)
      return unless value

      {
        mode: row["mode"],
        concurrency: row["concurrency"],
        processes: "#{row["processes"]} proc",
        metric:,
        value:,
        unit:
      }
    end

    def advantage_row(thread, fiber, metric, field, lower_is_better:)
      thread_value = metric_value(thread, field)
      fiber_value = metric_value(fiber, field)
      return unless thread_value&.positive? && fiber_value

      delta = ((fiber_value - thread_value) / thread_value) * 100.0
      delta *= -1 if lower_is_better
      {
        concurrency: thread["concurrency"],
        processes: "#{thread["processes"]} proc",
        metric:,
        value: delta
      }
    end

    def write_headline_charts
      datasets = datasets_by_family
      solid_queue = datasets.fetch("solid-queue")
      async_job = datasets.fetch("async-job")
      charts = []

      charts << write_chart("headline-solid-queue-fiber-vs-thread", throughput_range_spec(
        title: "Solid Queue fiber over thread",
        values: headline_deltas(solid_queue, comparison: :fiber_vs_thread),
        x_title: "Fiber throughput advantage over thread (%)"
      ))

      charts << write_chart("headline-async-job-vs-solid-queue-fiber", throughput_range_spec(
        title: "Async::Job over Solid Queue fiber",
        values: headline_deltas(solid_queue, async_job:, comparison: :async_job_vs_solid_queue),
        x_title: "Async::Job throughput advantage over Solid Queue fiber (%)"
      ))

      charts.compact
    end

    def headline_deltas(solid_queue, async_job: nil, comparison:)
      HEADLINE_WORKLOADS.flat_map do |workload|
        sq_dataset = solid_queue.find { |dataset| dataset.workload == workload }
        next [] unless sq_dataset

        case comparison
        when :fiber_vs_thread
          paired_rows(sq_dataset.successful_rows).map do |thread, fiber|
            delta_for_chart(workload, thread, fiber)
          end
        when :async_job_vs_solid_queue
          aj_dataset = async_job&.find { |dataset| dataset.workload == workload }
          next [] unless aj_dataset

          sq_fiber = sq_dataset.successful_rows.select { |row| row["mode"] == "fiber" }
          aj_rows = aj_dataset.successful_rows
          paired_backend_rows(sq_fiber, aj_rows).map do |sq, aj|
            delta_for_chart(workload, sq, aj)
          end
        end
      end
    end

    def paired_backend_rows(left_rows, right_rows)
      right_by_cell = right_rows.to_h { |row| [ [ row["concurrency"], row["processes"] ], row ] }
      left_rows.filter_map do |left|
        right = right_by_cell[[ left["concurrency"], left["processes"] ]]
        [ left, right ] if right
      end
    end

    def delta_for_chart(workload, left, right)
      left_value = metric_value(left, "jobs_per_second")
      right_value = metric_value(right, "jobs_per_second")
      return unless left_value&.positive? && right_value

      {
        workload: label_for_workload(workload),
        concurrency: left["concurrency"],
        processes: "#{left["processes"]} proc",
        value: ((right_value - left_value) / left_value) * 100.0
      }
    end

    def throughput_range_spec(title:, values:, x_title:)
      values = values.compact
      summaries = throughput_delta_summaries(values)

      {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
        "width" => 720,
        "height" => { "step" => 46 },
        "layer" => [
          {
            "mark" => { "type" => "rule", "color" => "#111827", "strokeWidth" => 1.5, "opacity" => 0.75 },
            "encoding" => {
              "x" => headline_x_encoding(x_title).merge("datum" => 0)
            }
          },
          {
            "data" => { "values" => summaries },
            "mark" => { "type" => "rule", "strokeWidth" => 8, "color" => "#94a3b8", "opacity" => 0.55 },
            "encoding" => {
              "x" => headline_x_encoding(x_title).merge("field" => "min"),
              "x2" => { "field" => "max" },
              "y" => headline_y_encoding,
              "tooltip" => tooltip_fields(%w[workload min max average cells])
            }
          },
          {
            "data" => { "values" => values },
            "mark" => { "type" => "point", "filled" => true, "size" => 58, "opacity" => 0.72 },
            "encoding" => {
              "x" => headline_x_encoding(x_title),
              "y" => headline_y_encoding,
              "color" => { "field" => "workload", "type" => "nominal", "legend" => nil, "scale" => { "scheme" => "tableau10" } },
              "tooltip" => tooltip_fields(%w[workload concurrency processes value])
            }
          },
          {
            "data" => { "values" => summaries },
            "mark" => { "type" => "point", "filled" => true, "shape" => "diamond", "size" => 150, "color" => "#111827" },
            "encoding" => {
              "x" => headline_x_encoding(x_title).merge("field" => "average"),
              "y" => headline_y_encoding,
              "tooltip" => tooltip_fields(%w[workload average min max cells])
            }
          },
          {
            "data" => { "values" => summaries },
            "mark" => { "type" => "text", "align" => "left", "baseline" => "middle", "dx" => 10, "fontSize" => 12, "fontWeight" => "bold", "color" => "#111827" },
            "encoding" => {
              "x" => headline_x_encoding(x_title).merge("field" => "average"),
              "y" => headline_y_encoding,
              "text" => { "field" => "average_label" }
            }
          }
        ],
        "config" => chart_config
      }
    end

    def throughput_delta_summaries(values)
      values.group_by { |row| row[:workload] }.map do |workload, rows|
        deltas = rows.map { |row| row[:value] }
        average = deltas.sum / deltas.size
        {
          workload:,
          min: deltas.min,
          max: deltas.max,
          average:,
          average_label: "avg #{fmt_percent(average)}",
          cells: deltas.size
        }
      end.sort_by { |row| workload_sort_key(WORKLOADS.key(row[:workload]) || row[:workload].downcase.tr(" ", "_")) }
    end

    def headline_x_encoding(title)
      {
        "field" => "value",
        "type" => "quantitative",
        "title" => title,
        "scale" => { "zero" => true, "nice" => true },
        "axis" => { "format" => "+.0f" }
      }
    end

    def headline_y_encoding
      { "field" => "workload", "type" => "nominal", "title" => nil, "sort" => headline_workload_labels }
    end

    def headline_workload_labels
      HEADLINE_WORKLOADS.map { |workload| label_for_workload(workload) }
    end

    def write_stress_charts
      stress = datasets_by_family.fetch("solid-queue-stress")
      return [] if stress.empty?

      [ write_chart("stress-cell-status", stress_status_spec(stress)) ].compact
    end

    def stress_status_spec(datasets)
      values = datasets.flat_map do |dataset|
        concurrencies = Array(dataset.data["concurrencies"])
        processes = Array(dataset.data["processes"])
        modes = Array(dataset.data["modes"])
        completed = dataset.rows.to_h { |row| [ [ row["mode"], row["concurrency"], row["processes"] ], true ] }

        modes.flat_map do |mode|
          processes.flat_map do |process|
            concurrencies.map do |concurrency|
              {
                workload: label_for_workload(dataset.workload),
                mode:,
                concurrency:,
                processes: process,
                status: completed[[ mode, concurrency, process ]] ? "completed" : "failed"
              }
            end
          end
        end
      end

      {
        "$schema" => VEGA_SCHEMA,
        "title" => "Solid Queue Stress Cell Status",
        "data" => { "values" => values },
        "mark" => { "type" => "point", "filled" => true, "size" => 130 },
        "encoding" => {
          "x" => { "field" => "concurrency", "type" => "ordinal", "title" => "Concurrency" },
          "y" => { "field" => "processes", "type" => "ordinal", "title" => "Processes" },
          "color" => { "field" => "status", "type" => "nominal", "scale" => { "domain" => %w[completed failed], "range" => %w[#10b981 #ef4444] } },
          "shape" => { "field" => "mode", "type" => "nominal", "sort" => %w[thread fiber] },
          "row" => { "field" => "workload", "type" => "nominal", "sort" => headline_workload_labels },
          "column" => { "field" => "mode", "type" => "nominal", "sort" => %w[thread fiber] },
          "tooltip" => tooltip_fields(%w[workload mode concurrency processes status])
        },
        "config" => chart_config
      }
    end

    def stress_metric_spec(datasets, metric, title, scale: 1.0)
      values = datasets.flat_map do |dataset|
        dataset.rows.map do |row|
          value = metric_value(row, metric)
          next unless value

          {
            workload: label_for_workload(dataset.workload),
            mode: row["mode"],
            concurrency: row["concurrency"],
            processes: "#{row["processes"]} proc",
            value: value * scale
          }
        end
      end.compact

      line_spec(
        title: "Solid Queue Stress #{title}",
        values:,
        y_title: title,
        facet_row: "workload",
        facet_column: "processes",
        facet_row_sort: headline_workload_labels,
        width: 180,
        height: 120
      )
    end

    def line_spec(title:, values:, y_title:, color_field: "mode", stroke_dash_field: nil, facet_row: nil, facet_column: nil, facet_row_sort: nil, facet_column_sort: nil, color_sort: nil, width: nil, height: nil)
      spec = {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
        "width" => width,
        "height" => height,
        "data" => { "values" => values },
        "mark" => { "type" => "line", "point" => true, "tooltip" => true },
        "encoding" => {
          "x" => { "field" => "concurrency", "type" => "quantitative", "title" => "Concurrency" },
          "y" => { "field" => "value", "type" => "quantitative", "title" => y_title },
          "color" => { "field" => color_field, "type" => "nominal" },
          "tooltip" => tooltip_fields(%w[mode concurrency processes metric percentile value])
        },
        "config" => chart_config
      }
      spec["encoding"]["color"]["sort"] = color_sort if color_sort
      spec["encoding"]["strokeDash"] = { "field" => stroke_dash_field, "type" => "nominal" } if stroke_dash_field
      spec["encoding"]["row"] = { "field" => facet_row, "type" => "nominal", "sort" => facet_row_sort } if facet_row
      spec["encoding"]["column"] = { "field" => facet_column, "type" => "nominal", "sort" => facet_column_sort } if facet_column
      spec["resolve"] = { "scale" => { "y" => "independent" } } if facet_row
      spec.compact
    end

    def bar_spec(title:, values:, y_title:, facet_column:, facet_column_sort: nil, width: nil, height: nil)
      {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
        "data" => { "values" => values },
        "facet" => {
          "column" => { "field" => facet_column, "type" => "nominal", "sort" => facet_column_sort }
        },
        "spec" => {
          "width" => width,
          "height" => height,
          "layer" => [
            {
              "mark" => { "type" => "rule", "color" => "#111827", "strokeWidth" => 1.5, "opacity" => 0.75 },
              "encoding" => {
                "y" => { "datum" => 0, "type" => "quantitative", "title" => y_title }
              }
            },
            {
              "mark" => { "type" => "bar", "tooltip" => true },
              "encoding" => {
                "x" => { "field" => "concurrency", "type" => "ordinal", "title" => "Concurrency" },
                "xOffset" => { "field" => "processes", "type" => "nominal", "sort" => PROCESS_LABELS },
                "y" => { "field" => "value", "type" => "quantitative", "title" => y_title, "stack" => nil },
                "color" => { "field" => "processes", "type" => "nominal", "sort" => PROCESS_LABELS },
                "tooltip" => tooltip_fields(%w[metric concurrency processes value])
              }
            }
          ]
        },
        "resolve" => { "scale" => { "y" => "independent" } },
        "config" => chart_config
      }.compact
    end

    def tooltip_fields(fields)
      quantitative = %w[value min max average cells concurrency]

      fields.map do |field|
        { "field" => field, "type" => quantitative.include?(field) ? "quantitative" : "nominal" }
      end
    end

    def chart_config
      {
        "background" => "white",
        "axis" => {
          "labelFont" => "Helvetica",
          "titleFont" => "Helvetica",
          "labelFontSize" => 12,
          "titleFontSize" => 12,
          "labelColor" => "#111827",
          "titleColor" => "#111827",
          "domainColor" => "#111827",
          "tickColor" => "#9ca3af",
          "grid" => true,
          "gridColor" => "#e5e7eb"
        },
        "header" => {
          "labelFont" => "Helvetica",
          "titleFont" => "Helvetica",
          "labelFontSize" => 12,
          "titleFontSize" => 12,
          "labelColor" => "#111827",
          "titleColor" => "#111827"
        },
        "legend" => {
          "labelFont" => "Helvetica",
          "titleFont" => "Helvetica",
          "labelFontSize" => 12,
          "titleFontSize" => 12,
          "labelColor" => "#111827",
          "titleColor" => "#111827"
        },
        "title" => { "font" => "Helvetica", "fontSize" => 16, "anchor" => "start", "color" => "#111827" },
        "view" => { "stroke" => nil }
      }
    end

    def write_chart(name, spec)
      FileUtils.mkdir_p(@charts_dir)
      path = File.join(@charts_dir, "#{name}.vg.json")
      File.write(path, JSON.pretty_generate(spec) + "\n")
      export_svg(path)
      path
    end

    def export_svg(json_path)
      svg_path = json_path.sub(/\.vg\.json\z/, ".svg")
      if command_available?("vl2svg")
        system("vl2svg", json_path, svg_path)
      elsif File.executable?(File.join("node_modules", ".bin", "vl2svg"))
        system(File.join("node_modules", ".bin", "vl2svg"), json_path, svg_path)
      else
        false
      end
    end

    def command_available?(name)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
    end

    def write_narrative
      path = File.join(@results_root, "narrative.md")
      prompt_path = File.expand_path("report_prompt.md", __dir__)
      summary = public_report_facts(headline_charts: [], stress_charts: [], narrative: path)
      narrative = generate_markdown(prompt_path, summary) || deterministic_narrative(summary)
      File.write(path, narrative.strip + "\n")
      path
    end

    def report_facts
      datasets_by_family.transform_values do |datasets|
        datasets.map do |dataset|
          summary = dataset_summary(dataset)
          {
            workload: dataset.workload,
            label: label_for_workload(dataset.workload),
            payload: dataset.payload,
            repeat: dataset.repeat,
            db_pool: dataset.db_pool,
            tests: summary[:tests],
            best_throughput: summary[:best_throughput]&.slice("mode", "concurrency", "processes", "jobs_per_second", "db_pool"),
            best_fiber_throughput: summary[:best_fiber_throughput]&.slice("mode", "concurrency", "processes", "jobs_per_second", "db_pool"),
            lowest_rss: summary[:lowest_rss]&.slice("mode", "concurrency", "processes", "peak_rss_kb", "db_pool"),
            lowest_cpu: summary[:lowest_cpu]&.slice("mode", "concurrency", "processes", "avg_cpu_pct", "db_pool"),
            lowest_latency: summary[:lowest_latency]&.slice("mode", "concurrency", "processes", "total_latency_ms", "db_pool"),
            throughput_win_rate: summary[:throughput_win_rate],
            average_fiber_delta: summary[:average_throughput_delta],
            best_fiber_delta: summary[:throughput_delta]&.slice(:value, :concurrency, :processes),
            best_rss_delta: summary[:rss_delta]&.slice(:value, :concurrency, :processes),
            best_cpu_delta: summary[:cpu_delta]&.slice(:value, :concurrency, :processes),
            best_latency_delta: summary[:latency_delta]&.slice(:value, :concurrency, :processes)
          }
        end
      end
    end

    def generate_markdown(prompt_path, facts)
      return unless ENV["OPENAI_API_KEY"]

      begin
        configure_ruby_llm
        prompt = File.read(prompt_path)
        response = RubyLLM.chat(model: ENV.fetch("BENCH_REPORT_MODEL", "gpt-5.5"))
          .with_instructions(prompt)
          .ask(JSON.pretty_generate(facts))
        strip_markdown_fence(response.content.to_s)
      rescue StandardError => error
        warn "Markdown generation skipped: #{error.class}: #{error.message}"
        nil
      end
    end

    def configure_ruby_llm
      return if @ruby_llm_configured

      require "ruby_llm"
      RubyLLM.configure { |config| config.openai_api_key = ENV.fetch("OPENAI_API_KEY") }
      RubyLLM.models.refresh!
      @ruby_llm_configured = true
    end

    def strip_markdown_fence(content)
      markdown = content.to_s.strip
      markdown = markdown.sub(/\A```(?:markdown)?\s*/i, "").sub(/\s*```\z/, "").strip
      markdown.empty? ? nil : markdown
    end

    def deterministic_narrative(facts)
      lines = []
      solid_queue = facts.dig(:results, "solid-queue") || []
      async_job = facts.dig(:results, "async-job") || []
      stress = facts.dig(:results, "solid-queue-stress") || []
      headline = solid_queue.select { |dataset| HEADLINE_WORKLOADS.include?(dataset[:workload]) }
      db = solid_queue.select { |dataset| DB_WORKLOADS.include?(dataset[:workload]) }

      lines << "# Solid Queue Fiber Benchmark Summary"
      lines << ""
      lines << "Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative."
      lines << ""
      lines << "On the headline Solid Queue workloads, the best-throughput point landed on `fiber` in every checked-in row. That does not mean `fiber` wins every paired cell; it means the best observed point in this same-backend comparison favored `fiber` for `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`."
      lines << ""
      lines << "The larger gains are on wait-heavy work. CPU is the control and stays much closer. The supplementary DB workloads also favor `fiber` at the best observed points in this dataset, and `db_transaction` is run with a matched pool so it stays an apples-to-apples executor comparison."
      lines << ""
      if async_job.any?
        lines << "Async::Job is faster than Solid Queue fiber on the comparable headline workloads in this run, but it changes the backend to Redis. Treat that as a backend comparison, not evidence about Solid Queue `thread` vs `fiber`."
        lines << ""
      end
      lines << "## What The Benchmarks Answer"
      lines << ""
      lines << "### Headline workloads"
      lines << ""
      lines << "| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Best Solid Queue throughput |"
      lines << "|---|---:|---:|---:|---:|"
      headline.sort_by { |dataset| workload_sort_key(dataset[:workload]) }.each do |dataset|
        best = dataset.dig(:best_throughput, "jobs_per_second")
        wins = dataset[:throughput_win_rate]
        lines << "| #{dataset[:label]} | #{wins[:wins]}/#{wins[:pairs]} | #{average_delta_text(dataset[:average_fiber_delta])} | #{delta_text(dataset[:best_fiber_delta])} | #{dataset.dig(:best_throughput, "mode")}, #{fmt_number(best)} jobs/s |"
      end
      lines << ""
      lines << "### DB workloads"
      lines << ""
      lines << "| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Interpretation |"
      lines << "|---|---:|---:|---:|---|"
      db.sort_by { |dataset| workload_sort_key(dataset[:workload]) }.each do |dataset|
        wins = dataset[:throughput_win_rate]
        interpretation = case dataset[:workload]
        when "db_queries"
          "Short DB bursts with no external wait."
        when "db_mixed"
          "Read state, call the delay server, then write results."
        when "db_transaction"
          "Matched-pool transaction run; fair executor comparison."
        end
        lines << "| #{dataset[:label]} | #{wins[:wins]}/#{wins[:pairs]} | #{average_delta_text(dataset[:average_fiber_delta])} | #{delta_text(dataset[:best_fiber_delta])} | #{interpretation} |"
      end
      lines << ""
      lines << "### Stress"
      lines << ""
      lines << "The stress suite is about completion, not about headline throughput. It removes the normal total-concurrency cap and shows the current Solid Queue failure envelope under high connection demand."
      lines << ""
      lines << "| Workload | Thread completed | Fiber completed |"
      lines << "|---|---:|---:|"
      facts.fetch(:stress_completion).each do |row|
        lines << "| #{row[:label]} | #{row.dig(:modes, "thread", :completed)}/#{row.dig(:modes, "thread", :planned)} | #{row.dig(:modes, "fiber", :completed)}/#{row.dig(:modes, "fiber", :planned)} |"
      end
      lines << ""
      lines << "Read this as a current Solid Queue implementation result, especially around how connection demand scales at high thread counts. It should not be treated as a permanent or fundamental property of threads."
      lines << ""
      lines << "### Async::Job Comparison"
      lines << ""
      lines << "| Workload | Async::Job best throughput | Solid Queue fiber best throughput |"
      lines << "|---|---:|---:|"
      async_job.sort_by { |dataset| workload_sort_key(dataset[:workload]) }.each do |dataset|
        solid_queue_row = headline.find { |row| row[:workload] == dataset[:workload] }
        lines << "| #{dataset[:label]} | #{fmt_number(dataset.dig(:best_throughput, "jobs_per_second"))} jobs/s | #{fmt_number(solid_queue_row&.dig(:best_fiber_throughput, "jobs_per_second"))} jobs/s |"
      end
      lines << ""
      lines << "## Caveats"
      lines << ""
      lines << "- The data shows best and lowest observed results from the tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size."
      lines << "- The public report excludes the old `db_transaction_pool_pressure` experiment because it is not an apples-to-apples executor comparison."
      lines << "- `db_transaction` is the fair transaction comparison because the DB pool is matched for both modes."
      lines << "- Async::Job changes the backend."
      lines.join("\n")
    end

    def chart_title(path)
      title = File.basename(path, ".vg.json").tr("-", " ").split.map do |word|
        case word
        when "db" then "DB"
        when "http" then "HTTP"
        when "llm" then "LLM"
        when "rss" then "RSS"
        when "cpu" then "CPU"
          else word.capitalize
        end
      end.join(" ")
      title.sub(/\AAsync Job /, "Async::Job ")
    end
  end
end
