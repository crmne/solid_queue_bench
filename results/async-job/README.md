# Async::Job Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T03:19:32Z`

Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|
| Sleep | 9/9 | fiber, c=10, proc=6, 643.40 jobs/s | fiber, c=50, proc=1, 145.68 MB | fiber, c=10, proc=6, 863.95 ms | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/async-job-sleep-grid.vg.json) / [Latency](../charts/async-job-sleep-latency.vg.json) |
| Async::HTTP | 9/9 | fiber, c=10, proc=6, 631.55 jobs/s | fiber, c=50, proc=1, 147.24 MB | fiber, c=10, proc=6, 907.60 ms | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/async-job-async-http-grid.vg.json) / [Latency](../charts/async-job-async-http-latency.vg.json) |
| RubyLLM Stream | 9/9 | fiber, c=10, proc=6, 13.96 jobs/s | fiber, c=5, proc=1, 172.91 MB | fiber, c=10, proc=6, 1308.28 ms | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/async-job-ruby-llm-stream-grid.vg.json) / [Latency](../charts/async-job-ruby-llm-stream-latency.vg.json) |
| CPU | 9/9 | fiber, c=10, proc=6, 123.89 jobs/s | fiber, c=5, proc=1, 126.52 MB | fiber, c=5, proc=6, 2044.87 ms | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/async-job-cpu-grid.vg.json) / [Latency](../charts/async-job-cpu-latency.vg.json) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
