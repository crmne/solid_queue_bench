# Solid Queue Stress Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T12:59:02Z`

| Workload | Cells | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 11/20 | async, cap=100, proc=6, 726.78 jobs/s | async, cap=25, proc=2, 236.55 MB | async, cap=50, proc=6, 586.06 ms | +5.6% at cap=25, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) / [Advantage](async-http-advantage.png) / [Latency](async-http-latency.png) |
| RubyLLM Stream | 11/20 | async, cap=50, proc=6, 8.72 jobs/s | async, cap=25, proc=2, 427.11 MB | async, cap=25, proc=6, 23206.81 ms | +7.4% at cap=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) / [Advantage](ruby-llm-stream-advantage.png) / [Latency](ruby-llm-stream-latency.png) |
| Sleep | 11/20 | async, cap=100, proc=6, 779.32 jobs/s | thread, cap=25, proc=2, 230.54 MB | async, cap=50, proc=6, 534.57 ms | +9.4% at cap=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- `Cells` is `completed/planned`, so incomplete matrices are visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
