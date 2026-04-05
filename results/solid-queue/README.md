# Solid Queue Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T01:02:12Z`

| Workload | Cells | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 18/18 | thread, cap=10, proc=6, 443.95 jobs/s | async, cap=25, proc=1, 117.07 MB | thread, cap=10, proc=6, 1334.19 ms | +20.6% at cap=50, proc=1 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) / [Advantage](async-http-advantage.png) / [Latency](async-http-latency.png) |
| CPU | 18/18 | async, cap=10, proc=6, 110.94 jobs/s | async, cap=5, proc=1, 120.70 MB | async, cap=10, proc=6, 2287.46 ms | +4.3% at cap=50, proc=1 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) / [Advantage](cpu-advantage.png) / [Latency](cpu-latency.png) |
| RubyLLM Stream | 18/18 | async, cap=5, proc=6, 6.80 jobs/s | async, cap=5, proc=1, 120.79 MB | async, cap=5, proc=6, 2851.07 ms | +17.2% at cap=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) / [Advantage](ruby-llm-stream-advantage.png) / [Latency](ruby-llm-stream-latency.png) |
| Sleep | 18/18 | async, cap=10, proc=6, 509.75 jobs/s | thread, cap=25, proc=1, 116.16 MB | async, cap=10, proc=6, 1157.94 ms | +16.8% at cap=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |
| Net::HTTP | 30/42 | async, cap=200, proc=6, 986.95 jobs/s | async, cap=25, proc=1, 115.66 MB | async, cap=100, proc=6, 616.02 ms | +20.1% at cap=50, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](http-grid.png) / [Advantage](http-advantage.png) / [Latency](http-latency.png) |
| LLM Batch | 42/42 | async, cap=25, proc=2, 9.77 jobs/s | async, cap=100, proc=1, 114.11 MB | async, cap=5, proc=6, 5093.15 ms | +4.1% at cap=150, proc=2 | [CSV](llm-batch-data.csv) / [JSON](llm-batch-data.json) / [Grid](llm-batch-grid.png) / [Advantage](llm-batch-advantage.png) / [Latency](llm-batch-latency.png) |
| LLM Stream | 42/42 | thread, cap=5, proc=6, 4.12 jobs/s | async, cap=10, proc=1, 120.78 MB | async, cap=5, proc=6, 4773.05 ms | +30.8% at cap=25, proc=2 | [CSV](llm-stream-data.csv) / [JSON](llm-stream-data.json) / [Grid](llm-stream-grid.png) / [Advantage](llm-stream-advantage.png) / [Latency](llm-stream-latency.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- `Cells` is `completed/planned`, so incomplete matrices are visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
