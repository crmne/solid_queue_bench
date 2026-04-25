# Solid Queue Stress Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-25T02:42:04Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 11/20 | fiber, c=100, proc=6, 807.53 jobs/s | fiber, c=25, proc=2, 270.08 MB | fiber, c=50, proc=6, 532.34 ms | +6.2% across 1 cells | +6.2% at c=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-stress-sleep-grid.svg) / [Advantage](../charts/solid-queue-stress-sleep-advantage.svg) / [Latency](../charts/solid-queue-stress-sleep-latency.svg) |
| Async::HTTP | 11/20 | fiber, c=100, proc=6, 739.49 jobs/s | fiber, c=25, proc=2, 272.03 MB | fiber, c=50, proc=6, 572.77 ms | +6.4% across 1 cells | +6.4% at c=25, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-stress-async-http-grid.svg) / [Advantage](../charts/solid-queue-stress-async-http-advantage.svg) / [Latency](../charts/solid-queue-stress-async-http-latency.svg) |
| RubyLLM Stream | 11/20 | fiber, c=50, proc=6, 8.86 jobs/s | fiber, c=25, proc=2, 287.91 MB | fiber, c=25, proc=6, 22877.27 ms | +7.8% across 1 cells | +7.8% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-stress-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-stress-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-stress-ruby-llm-stream-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
