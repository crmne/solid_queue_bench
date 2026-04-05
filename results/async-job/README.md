# Async::Job Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T01:15:23Z`

| Workload | Cells | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 9/9 | async, cap=10, proc=6, 635.14 jobs/s | async, cap=50, proc=1, 146.70 MB | async, cap=10, proc=6, 855.22 ms | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) |
| CPU | 9/9 | async, cap=10, proc=6, 123.94 jobs/s | async, cap=50, proc=1, 126.36 MB | async, cap=5, proc=6, 2040.85 ms | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) |
| RubyLLM Stream | 9/9 | async, cap=10, proc=6, 13.94 jobs/s | async, cap=5, proc=1, 174.25 MB | async, cap=10, proc=6, 1372.00 ms | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) |
| Sleep | 9/9 | async, cap=10, proc=6, 666.45 jobs/s | async, cap=50, proc=1, 145.22 MB | async, cap=10, proc=6, 840.70 ms | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- `Cells` is `completed/planned`, so incomplete matrices are visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
