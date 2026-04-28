# Solid Queue Stress Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-28T02:48:14Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 11/20 | fiber, c=100, proc=6, 799.45 jobs/s | fiber, c=25, proc=2, 270.67 MB | fiber, c=50, proc=6, 527.11 ms | +5.8% across 1 cells | +5.8% at c=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-stress-sleep-grid.svg) / [Advantage](../charts/solid-queue-stress-sleep-advantage.svg) / [Latency](../charts/solid-queue-stress-sleep-latency.svg) |
| Async::HTTP | 11/20 | fiber, c=100, proc=6, 731.75 jobs/s | thread, c=25, proc=2, 271.62 MB | fiber, c=50, proc=6, 559.70 ms | +10.3% across 1 cells | +10.3% at c=25, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-stress-async-http-grid.svg) / [Advantage](../charts/solid-queue-stress-async-http-advantage.svg) / [Latency](../charts/solid-queue-stress-async-http-latency.svg) |
| RubyLLM Stream | 10/20 | fiber, c=50, proc=6, 8.71 jobs/s | fiber, c=25, proc=2, 290.80 MB | fiber, c=25, proc=6, 23049.76 ms | n/a | n/a | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-stress-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-stress-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-stress-ruby-llm-stream-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
