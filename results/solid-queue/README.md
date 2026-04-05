# Solid Queue Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-04T22:19:42Z`

| Workload | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|
| Async::HTTP | async, cap=200, proc=6, 922.70 jobs/s | async, cap=10, proc=1, 116.83 MB | async, cap=100, proc=6, 648.36 ms | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) / [Advantage](async-http-advantage.png) / [Latency](async-http-latency.png) |
| CPU | async, cap=10, proc=6, 111.74 jobs/s | async, cap=200, proc=1, 117.30 MB | async, cap=50, proc=6, 2095.36 ms | +4.8% at cap=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) / [Advantage](cpu-advantage.png) / [Latency](cpu-latency.png) |
| RubyLLM Stream | async, cap=5, proc=6, 6.71 jobs/s | thread, cap=5, proc=1, 125.00 MB | async, cap=5, proc=6, 2915.63 ms | +23.8% at cap=100, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) / [Advantage](ruby-llm-stream-advantage.png) / [Latency](ruby-llm-stream-latency.png) |
| Sleep | async, cap=200, proc=6, 1076.70 jobs/s | thread, cap=25, proc=1, 116.26 MB | async, cap=100, proc=6, 601.22 ms | +19.9% at cap=50, proc=1 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |
| Net::HTTP | async, cap=200, proc=6, 986.95 jobs/s | async, cap=25, proc=1, 115.66 MB | async, cap=100, proc=6, 616.02 ms | +20.1% at cap=50, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](http-grid.png) / [Advantage](http-advantage.png) / [Latency](http-latency.png) |
| LLM Batch | async, cap=25, proc=2, 9.77 jobs/s | async, cap=100, proc=1, 114.11 MB | async, cap=5, proc=6, 5093.15 ms | +4.1% at cap=150, proc=2 | [CSV](llm-batch-data.csv) / [JSON](llm-batch-data.json) / [Grid](llm-batch-grid.png) / [Advantage](llm-batch-advantage.png) / [Latency](llm-batch-latency.png) |
| LLM Stream | thread, cap=5, proc=6, 4.12 jobs/s | async, cap=10, proc=1, 120.78 MB | async, cap=5, proc=6, 4773.05 ms | +30.8% at cap=25, proc=2 | [CSV](llm-stream-data.csv) / [JSON](llm-stream-data.json) / [Grid](llm-stream-grid.png) / [Advantage](llm-stream-advantage.png) / [Latency](llm-stream-latency.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
