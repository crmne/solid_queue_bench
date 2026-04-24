# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-24T12:51:06Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|
| Sleep | 18/18 | fiber, c=10, proc=6, 507.19 jobs/s | fiber, c=5, proc=1, 115.37 MB | fiber, c=10, proc=6, 1169.05 ms | +27.2% at c=10, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-sleep-grid.vg.json) / [Advantage](../charts/solid-queue-sleep-advantage.vg.json) / [Latency](../charts/solid-queue-sleep-latency.vg.json) |
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 512.25 jobs/s | fiber, c=10, proc=1, 116.66 MB | fiber, c=10, proc=6, 1163.77 ms | +26.0% at c=5, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-async-http-grid.vg.json) / [Advantage](../charts/solid-queue-async-http-advantage.vg.json) / [Latency](../charts/solid-queue-async-http-latency.vg.json) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 6.68 jobs/s | fiber, c=5, proc=1, 121.95 MB | fiber, c=5, proc=6, 2913.14 ms | +20.2% at c=10, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-ruby-llm-stream-grid.vg.json) / [Advantage](../charts/solid-queue-ruby-llm-stream-advantage.vg.json) / [Latency](../charts/solid-queue-ruby-llm-stream-latency.vg.json) |
| CPU | 18/18 | fiber, c=10, proc=6, 112.47 jobs/s | thread, c=5, proc=1, 120.25 MB | fiber, c=10, proc=6, 2258.74 ms | +5.1% at c=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/solid-queue-cpu-grid.vg.json) / [Advantage](../charts/solid-queue-cpu-advantage.vg.json) / [Latency](../charts/solid-queue-cpu-latency.vg.json) |
| DB Queries | 18/18 | fiber, c=10, proc=6, 386.43 jobs/s | fiber, c=10, proc=1, 116.36 MB | fiber, c=10, proc=6, 763.27 ms | +16.9% at c=25, proc=1 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.vg.json) / [Advantage](../charts/solid-queue-db-queries-advantage.vg.json) / [Latency](../charts/solid-queue-db-queries-latency.vg.json) |
| DB Mixed | 18/18 | fiber, c=10, proc=6, 336.69 jobs/s | fiber, c=10, proc=1, 116.34 MB | fiber, c=10, proc=6, 859.99 ms | +18.0% at c=25, proc=2 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.vg.json) / [Advantage](../charts/solid-queue-db-mixed-advantage.vg.json) / [Latency](../charts/solid-queue-db-mixed-latency.vg.json) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 198.07 jobs/s | fiber, c=25, proc=1, 115.85 MB | fiber, c=10, proc=6, 1498.53 ms | +24.6% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.vg.json) / [Advantage](../charts/solid-queue-db-transaction-advantage.vg.json) / [Latency](../charts/solid-queue-db-transaction-latency.vg.json) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
