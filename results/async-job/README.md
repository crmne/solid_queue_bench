# Async::Job Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-24T17:00:22Z`

Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|
| Sleep | 9/9 | fiber, c=25, proc=2, 635.94 jobs/s | fiber, c=50, proc=1, 155.13 MB | fiber, c=10, proc=6, 816.31 ms | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/async-job-sleep-grid.svg) / [Latency](../charts/async-job-sleep-latency.svg) |
| Async::HTTP | 9/9 | fiber, c=10, proc=6, 653.93 jobs/s | fiber, c=50, proc=1, 160.10 MB | fiber, c=10, proc=6, 796.57 ms | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/async-job-async-http-grid.svg) / [Latency](../charts/async-job-async-http-latency.svg) |
| RubyLLM Stream | 9/9 | fiber, c=10, proc=6, 16.87 jobs/s | fiber, c=50, proc=1, 155.04 MB | fiber, c=10, proc=6, 1160.51 ms | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/async-job-ruby-llm-stream-grid.svg) / [Latency](../charts/async-job-ruby-llm-stream-latency.svg) |
| CPU | 9/9 | fiber, c=5, proc=6, 120.18 jobs/s | fiber, c=5, proc=1, 139.16 MB | fiber, c=5, proc=6, 2066.02 ms | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/async-job-cpu-grid.svg) / [Latency](../charts/async-job-cpu-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
