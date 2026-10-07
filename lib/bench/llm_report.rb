require "json"
require "fileutils"

module Bench
  module LlmReport
    module_function

    def call(root = "results/ruby-llm")
      variants = %w[2.0 main-default main-reuse]
      labels = { "2.0" => "2.0", "main-default" => "main, default HTTP", "main-reuse" => "main, connection reuse" }
      datasets = variants.to_h do |variant|
        [variant, Dir["#{root}/#{variant}/*-data.json"].to_h { |path| [File.basename(path), JSON.parse(File.read(path))] }]
      end
      lines = ["# RubyLLM 2.0 vs upcoming 2.1", "",
        "Generated from the JSON and CSV artifacts beside this report. Each cell reports the median real run of three repetitions; JSON includes every repetition.", "",
        "Main's primary configuration enables the [connection reuse recommended for 2.1](https://rubyllm.com/next/configuration-connection/#connection-reuse): `net_http_persistent` in thread workers and `async_http` inside the fiber workers' Async reactor. The default-adapter main run separates this opt-in from the other version changes.", "",
        "All calls use a loopback fake OpenAI Chat Completions endpoint with HTTP/1.1 keep-alive. No external model calls, API charges, or TLS handshakes are involved. The connection counts measure accepted TCP connections serving LLM requests, not a simulated network-latency benefit.", "",
        "The full gem dependency manifests are embedded in each JSON. Both bundles use the same Rails and Solid Queue releases; main permits JSON 3 while 2.0 requires JSON 2, so this is a comparison of the latest compatible stacks.", "",
        "Both versions use the same PostgreSQL schema, including the additive 2.1 migrations, and the same model catalog. Migrations and history seeding run outside the timed jobs.", "",
        "| Configuration | RubyLLM revision | Rails | Solid Queue | JSON |",
        "|---|---|---|---|---|"]
      variants.each do |variant|
        env = datasets.fetch(variant).values.first&.fetch("environment")
        next unless env
        deps = env.fetch("dependencies")
        revision = deps.fetch("ruby_llm")["revision"] || deps.fetch("ruby_llm").fetch("version")
        lines << "| #{labels.fetch(variant)} | `#{revision}` | #{deps.fetch('rails').fetch('version')} | #{deps.fetch('solid_queue').fetch('version')} | #{deps.fetch('json').fetch('version')} |"
      end
      lines += ["", "The focused workloads follow [What’s New in 2.1](https://rubyllm.com/next/whats-new-in-2-1/).", "", "Workloads:", "",
        "- `ruby_llm_stream`: the existing persisted chat plus 40 streamed chunks, 20 ms apart, and downstream Turbo broadcast jobs. Same capped matrix as the headline suite.",
        "- `ruby_llm_stream_only`: 500 chunks without a provider delay, chat/message persistence, or broadcasts; validates chunk count and usage. Main additionally persists standalone usage-ledger rows. Measures streaming work within a queue job.",
        "- `ruby_llm_history`: rebuild a persisted 100-message chat ten times per job, with a fresh record each time. History and usage rows are seeded through real local calls before timing; Rails' default automatic scope inversing stays on.",
        "- `ruby_llm_requests`: 20 calls per job, each using a new chat. This exercises connection sharing across chats and jobs; each response is checked. Main also writes one usage-ledger row per request, whereas 2.0 does not.", "",
        "The repeated-call slowdown includes new usage persistence on this pinned main revision and development-mode SQL backtraces. [Controlled profiling](diagnostics/README.md) separates these costs: main is faster with equivalent persistence work. The original default-configuration measurements remain below.", "",
        "The focused cases use 50 jobs, concurrency 5 and 25, one worker process, and matched DB pools. Throughput is jobs per second. Timing starts after workers report ready; queue overhead and first-use initialization inside jobs remain included. These are application job measurements, not reproductions of RubyLLM's microbenchmark timings.", "",
        "Run `bin/compare_rubyllm` to run the comparison. It reuses a complete published 2.0 streaming baseline when its dependencies and matrix match; `--fresh` reruns that baseline too. `--resume` keeps already completed comparison datasets. Use `ruby -Ilib -rbench/llm_report -e 'Bench::LlmReport.call'` to regenerate this report.", ""]
      chart_rows = []
      summary_position = lines.size
      deltas = Hash.new { |hash, key| hash[key] = [] }
      datasets.fetch("2.0").each do |filename, baseline|
        lines += ["## #{baseline.fetch('backend')} / #{baseline.fetch('workload')}", "",
          "| Mode | Concurrency | Processes | 2.0 jobs/s | main default jobs/s | main reuse jobs/s | Reuse vs 2.0 | Reuse peak RSS (MB) | Reuse connections / calls |",
          "|---|---:|---:|---:|---:|---:|---:|---:|---|"]
        baseline.fetch("results").each do |row|
          identity = row.values_at("mode", "concurrency", "processes")
          matched = variants.to_h do |variant|
            match = datasets.fetch(variant).fetch(filename).fetch("results").find { |candidate| candidate.values_at("mode", "concurrency", "processes") == identity }
            raise "Missing paired cell: #{variant} #{filename} #{identity}" unless match
            [variant, match]
          end
          reuse = matched.fetch("main-reuse")
          delta = 100 * (reuse.fetch("jobs_per_second") / row.fetch("jobs_per_second") - 1)
          default_delta = 100 * (matched.fetch("main-default").fetch("jobs_per_second") / row.fetch("jobs_per_second") - 1)
          rss_delta = percent_change(reuse.fetch("peak_rss_kb"), row.fetch("peak_rss_kb"))
          cpu_delta = percent_change(reuse.fetch("avg_cpu_pct"), row.fetch("avg_cpu_pct"))
          latency_delta = percent_change(reuse.dig("total_latency_ms", "p50"), row.dig("total_latency_ms", "p50"))
          deltas[[baseline.fetch("backend"), baseline.fetch("workload"), row.fetch("mode")]] << [default_delta, delta, rss_delta, cpu_delta, latency_delta]
          connections = reuse["http_connections"]
          lines << "| #{identity.join(' | ')} | #{variants.map { |v| format('%.2f', matched.fetch(v).fetch('jobs_per_second')) }.join(' | ')} | #{format('%+.1f%%', delta)} | #{format('%.1f', reuse.fetch('peak_rss_kb') / 1024.0)} | #{connections ? "#{connections.fetch('connections')} / #{connections.fetch('requests')}" : 'n/a'} |"
          matched.each do |variant, sample|
            chart_rows << { workload: baseline.fetch("workload"), backend: baseline.fetch("backend"), mode: sample.fetch("mode"), cell: "#{sample.fetch('mode')} c=#{sample.fetch('concurrency')} p=#{sample.fetch('processes')}", configuration: labels.fetch(variant), jobs_per_second: sample.fetch("jobs_per_second") }
          end
        end
        lines += ["", "Artifacts: " + variants.map { |v| "[#{labels.fetch(v)} JSON](#{v}/#{filename}) / [CSV](#{v}/#{filename.sub('.json', '.csv')})" }.join("; "), ""]
        if baseline.fetch("workload") == "ruby_llm_requests"
          lines += ["Connection counts below sum the representative runs across the four cells. Every configuration performs the same number of requests.", "",
            "| Configuration | Accepted connections | Requests |", "|---|---:|---:|"]
          variants.each do |variant|
            rows = datasets.fetch(variant).fetch(filename).fetch("results")
            connections = rows.sum { |row| row.fetch("http_connections").fetch("connections") }
            requests = rows.sum { |row| row.fetch("http_connections").fetch("requests") }
            lines << "| #{labels.fetch(variant)} | #{connections} | #{requests} |"
          end
          lines << ""
        end
      end
      summary = ["## Paired throughput changes", "",
        "Each cell gets equal weight in these averages; the detailed tables and individual repetitions show variation across the tested matrix.", "",
        "| Backend | Workload | Mode | Cells | main default vs 2.0 | main reuse vs 2.0 |",
        "|---|---|---|---:|---:|---:|"]
      deltas.each do |key, values|
        averages = values.transpose.first(2).map { |column| average_change(column) }
        summary << "| #{key.join(' | ')} | #{values.size} | #{averages.join(' | ')} |"
      end
      summary += ["", "## Main with reuse: resources and latency", "",
        "Changes are relative to 2.0 in matching cells; negative values mean lower measurements. CPU is average worker utilization, not CPU time per job.", "",
        "| Backend | Workload | Mode | Peak RSS change | Average CPU change | p50 latency change |",
        "|---|---|---|---:|---:|---:|"]
      deltas.each do |key, values|
        averages = values.transpose.drop(2).map { |column| average_change(column) }
        summary << "| #{key.join(' | ')} | #{averages.join(' | ')} |"
      end
      lines.insert(summary_position, *summary, "")
      File.write("#{root}/comparison.json", JSON.pretty_generate(chart_rows) + "\n")
      spec = {
        "$schema" => "https://vega.github.io/schema/vega-lite/v6.json",
        data: { values: chart_rows },
        facet: { row: { field: "workload", type: "nominal" }, column: { field: "backend", type: "nominal" } },
        spec: { width: 450, height: { step: 40 }, mark: "bar", encoding: {
          y: { field: "cell", type: "nominal", title: nil },
          yOffset: { field: "configuration" },
          x: { field: "jobs_per_second", type: "quantitative", title: "Successful jobs / second" },
          color: { field: "configuration", title: nil }
        } },
        resolve: { scale: { x: "independent", y: "independent" } }
      }
      File.write("#{root}/comparison.vg.json", JSON.pretty_generate(spec) + "\n")
      system("node_modules/.bin/vl2svg", "#{root}/comparison.vg.json", "#{root}/comparison.svg", exception: true)
      lines += ["![RubyLLM throughput comparison](comparison.svg)", ""]
      File.write("#{root}/README.md", lines.join("\n"))
    end

    def percent_change(value, baseline)
      return unless value && baseline&.positive?

      100 * (value.to_f / baseline - 1)
    end

    def average_change(values)
      values = values.compact
      values.empty? ? "n/a" : format("%+.1f%%", values.sum / values.size)
    end
  end
end
