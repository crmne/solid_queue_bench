# Solid Queue Stress Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T12:59:02Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|
| Sleep | 11/20 | fiber, c=100, proc=6, 779.32 jobs/s | thread, c=25, proc=2, 230.54 MB | fiber, c=50, proc=6, 534.57 ms | +9.4% at c=25, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-stress-sleep-grid.vg.json) / [Advantage](../charts/solid-queue-stress-sleep-advantage.vg.json) / [Latency](../charts/solid-queue-stress-sleep-latency.vg.json) |
| Async::HTTP | 11/20 | fiber, c=100, proc=6, 726.78 jobs/s | fiber, c=25, proc=2, 236.55 MB | fiber, c=50, proc=6, 586.06 ms | +5.6% at c=25, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-stress-async-http-grid.vg.json) / [Advantage](../charts/solid-queue-stress-async-http-advantage.vg.json) / [Latency](../charts/solid-queue-stress-async-http-latency.vg.json) |
| RubyLLM Stream | 11/20 | fiber, c=50, proc=6, 8.72 jobs/s | fiber, c=25, proc=2, 427.11 MB | fiber, c=25, proc=6, 23206.81 ms | +7.4% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-stress-ruby-llm-stream-grid.vg.json) / [Advantage](../charts/solid-queue-stress-ruby-llm-stream-advantage.vg.json) / [Latency](../charts/solid-queue-stress-ruby-llm-stream-latency.vg.json) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
