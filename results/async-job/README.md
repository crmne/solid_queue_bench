# Async::Job Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-10-06T21:09:36Z`

Dependencies: rails `8.1.4`, solid_queue `1.7.0`, ruby_llm `2.0.0`.

Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 9/9 | fiber, c=25, proc=2, 721.05 jobs/s | fiber, c=50, proc=1, 152.72 MB | fiber, c=10, proc=6, 720.92 ms | n/a | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/async-job-sleep-grid.svg) / [Latency](../charts/async-job-sleep-latency.svg) |
| Async::HTTP | 9/9 | fiber, c=25, proc=2, 701.48 jobs/s | fiber, c=50, proc=1, 155.36 MB | fiber, c=25, proc=2, 867.34 ms | n/a | n/a | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/async-job-async-http-grid.svg) / [Latency](../charts/async-job-async-http-latency.svg) |
| RubyLLM Stream | 9/9 | fiber, c=10, proc=6, 12.46 jobs/s | fiber, c=50, proc=1, 194.64 MB | fiber, c=10, proc=6, 1405.59 ms | n/a | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/async-job-ruby-llm-stream-grid.svg) / [Latency](../charts/async-job-ruby-llm-stream-latency.svg) |
| CPU | 9/9 | fiber, c=5, proc=6, 164.64 jobs/s | fiber, c=5, proc=1, 132.18 MB | fiber, c=5, proc=6, 1557.86 ms | n/a | n/a | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/async-job-cpu-grid.svg) / [Latency](../charts/async-job-cpu-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
