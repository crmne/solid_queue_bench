# Async::Job Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T03:19:32Z`

Takeaway: Throughput-oriented reference point: `Async::Job` is faster in the headline tests here, but it is answering a different question because the backend changes as well as the execution model.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 9/9 | async, cap=10, proc=6, 631.55 jobs/s | async, cap=50, proc=1, 147.24 MB | async, cap=10, proc=6, 907.60 ms | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) |
| CPU | 9/9 | async, cap=10, proc=6, 123.89 jobs/s | async, cap=5, proc=1, 126.52 MB | async, cap=5, proc=6, 2044.87 ms | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) |
| RubyLLM Stream | 9/9 | async, cap=10, proc=6, 13.96 jobs/s | async, cap=5, proc=1, 172.91 MB | async, cap=10, proc=6, 1308.28 ms | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) |
| Sleep | 9/9 | async, cap=10, proc=6, 643.40 jobs/s | async, cap=50, proc=1, 145.68 MB | async, cap=10, proc=6, 863.95 ms | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` test.
- `Tests` is `completed/planned`, so missing or timed-out tests remain visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
