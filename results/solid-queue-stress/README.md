# Solid Queue Stress Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-27T02:47:14Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 20/20 | fiber, c=100, proc=6, 863.96 jobs/s | fiber, c=25, proc=2, 269.67 MB | fiber, c=50, proc=6, 507.48 ms | +2482.5% across 10 cells | +10226.8% at c=150, proc=6 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-stress-sleep-grid.svg) / [Advantage](../charts/solid-queue-stress-sleep-advantage.svg) / [Latency](../charts/solid-queue-stress-sleep-latency.svg) |
| Async::HTTP | 20/20 | fiber, c=100, proc=6, 778.64 jobs/s | fiber, c=25, proc=2, 271.55 MB | fiber, c=50, proc=6, 530.55 ms | +1607.9% across 10 cells | +3754.5% at c=150, proc=6 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-stress-async-http-grid.svg) / [Advantage](../charts/solid-queue-stress-async-http-advantage.svg) / [Latency](../charts/solid-queue-stress-async-http-latency.svg) |
| RubyLLM Stream | 11/20 | fiber, c=50, proc=6, 6.66 jobs/s | fiber, c=25, proc=2, 288.10 MB | fiber, c=25, proc=6, 32326.33 ms | -30.9% across 1 cells | -30.9% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-stress-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-stress-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-stress-ruby-llm-stream-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
