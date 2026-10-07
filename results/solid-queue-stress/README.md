# Solid Queue Stress Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-10-06T22:10:34Z`

Dependencies: rails `8.1.4`, solid_queue `1.7.0`, ruby_llm `2.0.0`.

Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 11/20 | fiber, c=100, proc=6, 952.20 jobs/s | fiber, c=25, proc=2, 250.09 MB | fiber, c=50, proc=6, 454.16 ms | +11.0% across 1 cells | +11.0% at c=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-stress-sleep-grid.svg) / [Advantage](../charts/solid-queue-stress-sleep-advantage.svg) / [Latency](../charts/solid-queue-stress-sleep-latency.svg) |
| Async::HTTP | 11/20 | fiber, c=150, proc=6, 757.23 jobs/s | fiber, c=25, proc=2, 260.46 MB | fiber, c=50, proc=6, 483.77 ms | -0.6% across 1 cells | -0.6% at c=25, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-stress-async-http-grid.svg) / [Advantage](../charts/solid-queue-stress-async-http-advantage.svg) / [Latency](../charts/solid-queue-stress-async-http-latency.svg) |
| RubyLLM Stream | 11/20 | fiber, c=50, proc=6, 12.12 jobs/s | fiber, c=25, proc=2, 444.03 MB | fiber, c=25, proc=6, 17169.48 ms | +26.5% across 1 cells | +26.5% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-stress-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-stress-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-stress-ruby-llm-stream-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
