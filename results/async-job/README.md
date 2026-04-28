# Async::Job Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-28T01:32:08Z`

Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 9/9 | fiber, c=25, proc=2, 628.53 jobs/s | fiber, c=50, proc=1, 156.39 MB | fiber, c=10, proc=6, 894.48 ms | n/a | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/async-job-sleep-grid.svg) / [Latency](../charts/async-job-sleep-latency.svg) |
| Async::HTTP | 9/9 | fiber, c=25, proc=2, 630.29 jobs/s | fiber, c=50, proc=1, 160.09 MB | fiber, c=10, proc=6, 852.88 ms | n/a | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/async-job-async-http-grid.svg) / [Latency](../charts/async-job-async-http-latency.svg) |
| RubyLLM Stream | 9/9 | fiber, c=10, proc=6, 16.68 jobs/s | fiber, c=50, proc=1, 157.72 MB | fiber, c=10, proc=6, 1148.28 ms | n/a | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/async-job-ruby-llm-stream-grid.svg) / [Latency](../charts/async-job-ruby-llm-stream-latency.svg) |
| CPU | 9/9 | fiber, c=10, proc=6, 123.66 jobs/s | fiber, c=50, proc=1, 139.64 MB | fiber, c=5, proc=6, 2047.36 ms | n/a | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/async-job-cpu-grid.svg) / [Latency](../charts/async-job-cpu-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
