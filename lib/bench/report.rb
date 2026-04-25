require "csv"
require "erb"
require "fileutils"
require "json"
require "open3"
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
    DB_WORKLOADS = %w[db_queries db_mixed db_transaction db_transaction_pool_pressure].freeze
    CONTROL_WORKLOADS = %w[http].freeze
    STRESS_WORKLOADS = %w[sleep async_http ruby_llm_stream].freeze

    FAMILY_SUMMARIES = {
      "solid-queue" => "Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison.",
      "async-job" => "Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.",
      "solid-queue-stress" => "Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells."
    }.freeze

    VEGA_SCHEMA = "https://vega.github.io/schema/vega-lite/v6.json"

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
      write_html_report
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
      lines << "| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta | Artifacts |"
      lines << "|---|---|---|---|---|---|---|"

      datasets.sort_by { |dataset| workload_sort_key(dataset.workload) }.each do |dataset|
        summary = dataset_summary(dataset)
        delta = summary[:throughput_delta]
        delta_text = delta ? "#{fmt_percent(delta[:value])} at c=#{delta[:concurrency]}, proc=#{delta[:processes]}" : "n/a"
        artifacts = [
          relative_link(dir, dataset.csv_path, "CSV"),
          relative_link(dir, dataset.json_path, "JSON")
        ] + chart_links(dir, dataset)

        lines << "| #{label_for_workload(dataset.workload)} | #{summary[:tests]} | #{fmt_cell(summary[:best_throughput], "jobs_per_second", unit: " jobs/s")} | #{fmt_cell(summary[:lowest_rss], "peak_rss_kb", scale: 1.0 / 1024.0, unit: " MB")} | #{fmt_cell(summary[:lowest_latency], "total_latency_p50_ms", unit: " ms")} | #{delta_text} | #{artifacts.join(' / ')} |"
      end

      lines << ""
      lines << "## Notes"
      lines << ""
      lines << "- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell."
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
      order = HEADLINE_WORKLOADS + DB_WORKLOADS + CONTROL_WORKLOADS
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
      lines << ""
      lines << "Interactive charts: #{relative_link(@results_root, File.join(@results_root, 'index.html'), 'index.html')}"

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
      {
        title: "Solid Queue Bench",
        audience: "Rails developers deciding whether to use Solid Queue fiber execution mode.",
        source_note: "Generated by bin/report from checked-in results JSON and CSV artifacts.",
        result_dates: result_date_range(all_datasets),
        solid_queue_revision: solid_queue_revision(all_datasets),
        research_questions: research_questions,
        methodology: methodology_notes,
        benchmark_matrix: benchmark_matrix_facts(all_datasets),
        workloads: workload_descriptions,
        results: report_facts,
        stress_completion: stress_completion_facts(datasets.fetch("solid-queue-stress", [])),
        charts: {
          headline: chart_facts(headline_charts),
          db: workload_chart_facts("solid-queue", DB_WORKLOADS, "advantage"),
          stress: chart_facts(stress_charts)
        },
        links: {
          generated_artifacts: "results/README.md",
          interactive_report: "results/index.html",
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
      lines << "Latest checked-in results: **#{facts[:result_dates]}**."
      lines << "Solid Queue commit under test: `#{facts[:solid_queue_revision]}`." if facts[:solid_queue_revision]
      lines << ""
      lines << "Full generated artifacts: [results](#{facts[:links][:generated_artifacts]}), [Solid Queue](#{facts[:links][:solid_queue_results]}), [Async::Job](#{facts[:links][:async_job_results]}), [stress](#{facts[:links][:stress_results]}), and the [interactive chart explorer](#{facts[:links][:interactive_report]})."
      lines << ""
      lines << "## Research Questions"
      lines << ""
      facts[:research_questions].each { |question| lines << "- #{question}" }
      lines << ""
      lines << "## Headline Results"
      lines << ""
      lines << "Inside Solid Queue, this is a same-backend comparison: the queue, Rails app, jobs, and matrix are the same; only the worker execution mode changes."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:headline]))
      lines << ""
      lines.concat(workload_summary_table(facts, "solid-queue"))
      lines << ""
      lines << "The strongest fiber gains show up where the jobs spend meaningful time waiting: RubyLLM streaming, HTTP, and sleep-shaped work. CPU remains close, which is the expected control. The DB workloads show that short DB bursts and read/API/write jobs still benefit from fiber, while transaction results need to be read with the pool configuration in mind."
      lines << ""
      lines << "## DB Workloads"
      lines << ""
      lines << "| Workload | What It Tests | Payload | DB Pool | Best Fiber Throughput Delta |"
      lines << "|---|---|---|---|---:|"
      db_result_rows(facts).each { |row| lines << row }
      lines << ""
      lines << "`DB Transaction` uses a matched pool (`concurrency + 5` per process for both modes), so it is the fair executor comparison. `DB Transaction Pool Pressure` keeps the default mode-specific pool behavior, so it answers the sizing-pressure question instead."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:db]))
      lines << ""
      lines << "## Stress Suite"
      lines << ""
      lines << "The headline suite caps total concurrency at `60` to keep the mode comparison fair. The stress suite removes that cap and asks where thread workers stop completing planned cells when connection demand grows."
      lines << ""
      lines.concat(chart_embeds(facts[:charts][:stress]))
      lines << ""
      lines << "| Workload | Fiber Cells | Thread Cells |"
      lines << "|---|---:|---:|"
      facts[:stress_completion].each do |row|
        lines << "| #{row[:label]} | #{row.dig(:modes, "fiber", :completed)}/#{row.dig(:modes, "fiber", :planned)} | #{row.dig(:modes, "thread", :completed)}/#{row.dig(:modes, "thread", :planned)} |"
      end
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
      lines << "Single-workload sweeps are available too, including `sweep:sleep`, `sweep:db_queries`, `sweep:db_transaction`, `sweep:db_mixed`, `sweep:db_transaction_pool_pressure`, `sweep:ruby_llm_stream`, and the `sweep:async_job_*` tasks."
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
        "The headline matrix caps total concurrency at `60` so high process counts do not turn the main comparison into a pool-exhaustion test.",
        "The stress matrix removes that cap to show where high-concurrency thread workers stop completing planned cells.",
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
        { name: "db_transaction_pool_pressure", shape: "Same transaction under default pools", purpose: "Supplementary pool-sizing pressure test" }
      ]
    end

    def benchmark_matrix_facts(datasets)
      datasets.group_by(&:family).transform_values do |family_datasets|
        first = family_datasets.first
        {
          workloads: family_datasets.map(&:workload).sort_by { |workload| workload_sort_key(workload) },
          concurrencies: first&.data&.fetch("concurrencies", nil),
          processes: first&.data&.fetch("processes", nil),
          modes: first&.data&.fetch("modes", nil),
          repeat: first&.repeat,
          max_total_concurrency: first&.data&.fetch("max_total_concurrency", nil)
        }
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
          "bundle exec rake sweep:publish                 # Full publishable suite"
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
        "Matched-pool DB transaction results answer runtime fairness; default-pool transaction pressure results answer sizing pressure.",
        "The harness uses aggressive queue polling, so these numbers reflect execution behavior under a low-latency benchmark configuration, not default production settings."
      ]
    end

    def chart_embeds(charts)
      charts.flat_map do |chart|
        line = chart[:embeddable] ? "![#{chart[:label]}](#{chart[:path]})" : "[#{chart[:label]}](#{chart[:path]})"
        [ line, "" ]
      end.tap(&:pop)
    end

    def workload_summary_table(facts, family)
      rows = facts[:results].fetch(family, []).sort_by { |result| workload_sort_key(result[:workload]) }
      lines = []
      lines << "| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta |"
      lines << "|---|---:|---|---|---|---:|"
      rows.each do |result|
        lines << "| #{result[:label]} | #{result[:tests]} | #{summary_cell(result[:best_throughput], "jobs_per_second", unit: " jobs/s")} | #{summary_cell(result[:lowest_rss], "peak_rss_kb", scale: 1.0 / 1024.0, unit: " MB")} | #{summary_cell(result[:lowest_latency], "total_latency_p50_ms", unit: " ms")} | #{delta_text(result[:best_fiber_delta])} |"
      end
      lines
    end

    def db_result_rows(facts)
      DB_WORKLOADS.filter_map do |workload|
        result = result_for(facts, "solid-queue", workload)
        next unless result

        description = workload_descriptions.find { |entry| entry[:name] == workload }
        db_pool = result[:db_pool] || "mode-specific"
        "| #{result[:label]} | #{description[:purpose]} | #{payload_text(result[:payload])} | #{db_pool} | #{delta_text(result[:best_fiber_delta])} |"
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
        facet_column: "processes"
      )
    end

    def workload_latency_spec(dataset, rows)
      values = rows.flat_map do |row|
        %w[p50 p95 p99 max].map do |percentile|
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
        facet_column: "processes"
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
        facet_column: "metric"
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
        values: headline_deltas(solid_queue, comparison: :fiber_vs_thread)
      ))

      charts << write_chart("headline-async-job-vs-solid-queue-fiber", throughput_range_spec(
        title: "Async::Job over Solid Queue fiber",
        values: headline_deltas(solid_queue, async_job:, comparison: :async_job_vs_solid_queue)
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

    def throughput_range_spec(title:, values:)
      strip_spec(
        title:,
        values: values.compact,
        x_title: "Throughput advantage (%)",
        y_field: "workload"
      )
    end

    def write_stress_charts
      stress = datasets_by_family.fetch("solid-queue-stress")
      return [] if stress.empty?

      [
        write_chart("stress-cell-status", stress_status_spec(stress)),
        write_chart("stress-throughput", stress_metric_spec(stress, "jobs_per_second", "Throughput (jobs/s)")),
        write_chart("stress-rss", stress_metric_spec(stress, "peak_rss_kb", "Peak RSS (MB)", scale: 1.0 / 1024.0))
      ].compact
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
          "shape" => { "field" => "mode", "type" => "nominal" },
          "row" => { "field" => "workload", "type" => "nominal" },
          "column" => { "field" => "mode", "type" => "nominal" },
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

      line_spec(title: "Solid Queue Stress #{title}", values:, y_title: title, facet_row: "workload", facet_column: "processes")
    end

    def line_spec(title:, values:, y_title:, color_field: "mode", stroke_dash_field: nil, facet_row: nil, facet_column: nil)
      spec = {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
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
      spec["encoding"]["strokeDash"] = { "field" => stroke_dash_field, "type" => "nominal" } if stroke_dash_field
      spec["encoding"]["row"] = { "field" => facet_row, "type" => "nominal" } if facet_row
      spec["encoding"]["column"] = { "field" => facet_column, "type" => "nominal" } if facet_column
      spec
    end

    def bar_spec(title:, values:, y_title:, facet_column:)
      {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
        "data" => { "values" => values },
        "mark" => { "type" => "bar", "tooltip" => true },
        "encoding" => {
          "x" => { "field" => "concurrency", "type" => "ordinal", "title" => "Concurrency" },
          "y" => { "field" => "value", "type" => "quantitative", "title" => y_title },
          "color" => { "field" => "processes", "type" => "nominal" },
          "column" => { "field" => facet_column, "type" => "nominal" },
          "tooltip" => tooltip_fields(%w[metric concurrency processes value])
        },
        "resolve" => { "scale" => { "y" => "independent" } },
        "config" => chart_config
      }
    end

    def strip_spec(title:, values:, x_title:, y_field:)
      {
        "$schema" => VEGA_SCHEMA,
        "title" => title,
        "data" => { "values" => values },
        "mark" => { "type" => "tick", "thickness" => 2, "size" => 22, "tooltip" => true },
        "encoding" => {
          "x" => { "field" => "value", "type" => "quantitative", "title" => x_title },
          "y" => { "field" => y_field, "type" => "nominal", "title" => nil },
          "color" => { "field" => y_field, "type" => "nominal", "legend" => nil },
          "tooltip" => tooltip_fields(%w[workload concurrency processes value])
        },
        "config" => chart_config
      }
    end

    def tooltip_fields(fields)
      fields.map { |field| { "field" => field, "type" => field == "value" ? "quantitative" : "nominal" } }
    end

    def chart_config
      {
        "background" => "white",
        "axis" => { "labelFont" => "Arial", "titleFont" => "Arial", "grid" => true },
        "legend" => { "labelFont" => "Arial", "titleFont" => "Arial" },
        "title" => { "font" => "Arial", "fontSize" => 16, "anchor" => "start" },
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
      summary = report_facts
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
      solid_queue = facts.fetch("solid-queue", [])
      async_job = facts.fetch("async-job", [])
      stress = facts.fetch("solid-queue-stress", [])

      lines << "# Solid Queue Fiber Benchmark Summary"
      lines << ""
      lines << "Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative."
      lines << ""
      lines << "In the main Solid Queue matrix, every checked-in workload completed its planned cells and the best-throughput point landed on `fiber`. That does not mean fiber wins at every setting; it means the best observed point in this matrix favored fiber for the same Solid Queue backend."
      lines << ""
      lines << "The larger gains are on wait-heavy work. CPU is the control and stays much closer. The DB workloads also favor fiber at the best observed points, but transaction results need to be read with the pool configuration: matched-pool transactions are the fair executor comparison, while the default-pool transaction pressure run is about database pool sizing."
      lines << ""
      if async_job.any?
        lines << "Async::Job is faster than Solid Queue fiber on the comparable headline workloads in this run, but it changes the backend to Redis. Treat that as a backend comparison, not evidence about Solid Queue `thread` vs `fiber`."
        lines << ""
      end
      lines << "## Solid Queue Fiber vs Thread"
      lines << ""
      lines << "| Workload | Tests | Best throughput | Best fiber delta |"
      lines << "|---|---:|---:|---:|"
      solid_queue.sort_by { |dataset| workload_sort_key(dataset[:workload]) }.each do |dataset|
        best = dataset.dig(:best_throughput, "jobs_per_second")
        lines << "| #{dataset[:label]} | #{dataset[:tests]} | #{fmt_number(best)} jobs/s | #{delta_text(dataset[:best_fiber_delta])} |"
      end
      lines << ""
      lines << "## Async::Job Comparison"
      lines << ""
      lines << "| Workload | Best throughput |"
      lines << "|---|---:|"
      async_job.sort_by { |dataset| workload_sort_key(dataset[:workload]) }.each do |dataset|
        best = dataset.dig(:best_throughput, "jobs_per_second")
        lines << "| #{dataset[:label]} | #{fmt_number(best)} jobs/s |"
      end
      lines << ""
      lines << "## Stress"
      lines << ""
      lines << "Stress results completed #{stress.map { |dataset| dataset[:tests] }.uniq.join(", ")} cells per workload family entry. Read these as failure-envelope runs, not the same fair matrix as the main Solid Queue suite."
      lines << ""
      lines << "## Caveats"
      lines << ""
      lines << "- The data shows best and lowest observed results from the tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size."
      lines << "- DB pool configuration changes the meaning of transaction results."
      lines << "- Async::Job changes the backend."
      lines.join("\n")
    end

    def write_html_report
      chart_paths = Dir.glob(File.join(@charts_dir, "*.vg.json")).sort_by { |path| chart_sort_key(path) }
      cards = chart_paths.map.with_index do |path, index|
        id = "chart-#{index}"
        relative = Pathname.new(path).relative_path_from(Pathname.new(@results_root)).to_s
        title = ERB::Util.html_escape(chart_title(path))
        group = ERB::Util.html_escape(chart_group(path))
        <<~HTML
          <section class="chart-card">
            <div class="card-kicker">#{group}</div>
            <h2>#{title}</h2>
            <div id="#{id}" class="chart"></div>
            <script>vegaEmbed('##{id}', '#{relative}', {actions: true, renderer: 'svg'});</script>
          </section>
        HTML
      end

      html = <<~HTML
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Solid Queue Bench Results</title>
          <script src="https://cdn.jsdelivr.net/npm/vega@6"></script>
          <script src="https://cdn.jsdelivr.net/npm/vega-lite@6"></script>
          <script src="https://cdn.jsdelivr.net/npm/vega-embed@7"></script>
          <style>
            :root {
              --ink: #18201f;
              --muted: #5f6966;
              --line: #d9ded7;
              --paper: #fffaf0;
              --card: rgba(255, 255, 255, 0.86);
              --accent: #0f766e;
              --accent-2: #b45309;
            }

            * { box-sizing: border-box; }
            body {
              margin: 0;
              color: var(--ink);
              font-family: "Avenir Next", "Segoe UI", sans-serif;
              background:
                radial-gradient(circle at top left, rgba(15, 118, 110, 0.18), transparent 34rem),
                radial-gradient(circle at 85% 10%, rgba(180, 83, 9, 0.16), transparent 28rem),
                linear-gradient(135deg, #fffaf0 0%, #eef4ef 100%);
            }
            main { max-width: 1240px; margin: 0 auto; padding: 48px 28px 72px; }
            .hero {
              display: grid;
              gap: 18px;
              margin-bottom: 34px;
              padding: 34px;
              border: 1px solid rgba(24, 32, 31, 0.12);
              border-radius: 28px;
              background: rgba(255, 250, 240, 0.72);
              box-shadow: 0 24px 70px rgba(24, 32, 31, 0.10);
            }
            h1 {
              max-width: 760px;
              margin: 0;
              font-family: Optima, "Avenir Next", sans-serif;
              font-size: clamp(38px, 7vw, 78px);
              line-height: 0.94;
              letter-spacing: -0.05em;
            }
            .hero p { max-width: 740px; margin: 0; color: var(--muted); font-size: 18px; line-height: 1.55; }
            .links { display: flex; flex-wrap: wrap; gap: 10px; }
            .links a {
              color: var(--ink);
              text-decoration: none;
              border: 1px solid var(--line);
              border-radius: 999px;
              padding: 8px 13px;
              background: rgba(255, 255, 255, 0.72);
            }
            .charts { display: grid; gap: 22px; }
            .chart-card {
              overflow: hidden;
              padding: 22px;
              border: 1px solid rgba(24, 32, 31, 0.12);
              border-radius: 24px;
              background: var(--card);
              box-shadow: 0 18px 46px rgba(24, 32, 31, 0.08);
            }
            .card-kicker {
              margin-bottom: 8px;
              color: var(--accent-2);
              font-size: 12px;
              font-weight: 800;
              letter-spacing: 0.12em;
              text-transform: uppercase;
            }
            h2 { margin: 0 0 18px; font-size: 22px; letter-spacing: -0.02em; }
            .chart { overflow-x: auto; }
            @media (max-width: 700px) {
              main { padding: 24px 14px 48px; }
              .hero { padding: 22px; border-radius: 20px; }
              .chart-card { padding: 16px; border-radius: 18px; }
            }
          </style>
        </head>
        <body>
          <main>
            <header class="hero">
              <h1>Solid Queue Bench Results</h1>
              <p>Generated from the checked-in benchmark artifacts. The Markdown summaries are optimized for reading; this page is for exploring the Vega charts directly.</p>
              <nav class="links">
                <a href="README.md">Results README</a>
                <a href="narrative.md">Narrative</a>
                <a href="solid-queue/README.md">Solid Queue</a>
                <a href="async-job/README.md">Async::Job</a>
                <a href="solid-queue-stress/README.md">Stress</a>
              </nav>
            </header>
            <div class="charts">
              #{cards.join("\n")}
            </div>
          </main>
        </body>
        </html>
      HTML

      File.write(File.join(@results_root, "index.html"), html)
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

    def chart_group(path)
      name = File.basename(path)
      if name.start_with?("headline-")
        "Headline"
      elsif name.start_with?("stress-") || name.start_with?("solid-queue-stress-")
        "Stress"
      elsif name.start_with?("async-job-")
        "Async::Job"
      else
        "Solid Queue"
      end
    end

    def chart_sort_key(path)
      name = File.basename(path)
      group_order = case chart_group(path)
      when "Headline" then 0
      when "Solid Queue" then 1
      when "Async::Job" then 2
      when "Stress" then 3
      else 4
      end
      [ group_order, name ]
    end
  end
end
