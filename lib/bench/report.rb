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
        lowest_rss: rows.min_by { |row| number(row["peak_rss_kb"]) || Float::INFINITY },
        lowest_cpu: rows.min_by { |row| number(row["avg_cpu_pct"]) || Float::INFINITY },
        lowest_latency: rows.min_by { |row| number(row.dig("total_latency_ms", "p50")) || Float::INFINITY },
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
      narrative = generate_narrative(prompt_path, summary) || deterministic_narrative(summary)
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
            lowest_rss: summary[:lowest_rss]&.slice("mode", "concurrency", "processes", "peak_rss_kb", "db_pool"),
            lowest_cpu: summary[:lowest_cpu]&.slice("mode", "concurrency", "processes", "avg_cpu_pct", "db_pool"),
            lowest_latency: summary[:lowest_latency]&.slice("mode", "concurrency", "processes", "total_latency_ms", "db_pool"),
            best_fiber_delta: summary[:throughput_delta]&.slice(:value, :concurrency, :processes),
            best_rss_delta: summary[:rss_delta]&.slice(:value, :concurrency, :processes),
            best_cpu_delta: summary[:cpu_delta]&.slice(:value, :concurrency, :processes),
            best_latency_delta: summary[:latency_delta]&.slice(:value, :concurrency, :processes)
          }
        end
      end
    end

    def generate_narrative(prompt_path, facts)
      return unless ENV["OPENAI_API_KEY"]

      begin
        require "ruby_llm"
        RubyLLM.configure { |config| config.openai_api_key = ENV.fetch("OPENAI_API_KEY") }
        RubyLLM.models.refresh!
        prompt = File.read(prompt_path)
        response = RubyLLM.chat(model: ENV.fetch("BENCH_REPORT_MODEL", "gpt-5.5"))
          .with_instructions(prompt)
          .ask(JSON.pretty_generate(facts))
        response.content.to_s
      rescue StandardError => error
        warn "Narrative generation skipped: #{error.class}: #{error.message}"
        nil
      end
    end

    def deterministic_narrative(facts)
      lines = []
      lines << "# Narrative Report"
      lines << ""
      lines << "Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative."
      lines << ""
      facts.each do |family, datasets|
        lines << "## #{label_for_family(family)}"
        lines << ""
        datasets.each do |dataset|
          delta = dataset[:best_fiber_delta]
          delta_text = delta ? "#{fmt_percent(delta[:value])} at c=#{delta[:concurrency]}, proc=#{delta[:processes]}" : "n/a"
          lines << "- #{dataset[:label]}: tests #{dataset[:tests]}, best fiber delta #{delta_text}."
        end
        lines << ""
      end
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
