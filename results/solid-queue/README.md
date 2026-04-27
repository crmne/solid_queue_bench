# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-24T16:44:56Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 18/18 | fiber, c=10, proc=6, 511.58 jobs/s | thread, c=5, proc=1, 133.94 MB | fiber, c=10, proc=6, 1177.70 ms | +5.9% across 9 cells | +20.4% at c=50, proc=1 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-sleep-grid.svg) / [Advantage](../charts/solid-queue-sleep-advantage.svg) / [Latency](../charts/solid-queue-sleep-latency.svg) |
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 498.99 jobs/s | fiber, c=10, proc=1, 135.14 MB | fiber, c=10, proc=6, 1210.55 ms | +7.0% across 9 cells | +21.2% at c=50, proc=1 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-async-http-grid.svg) / [Advantage](../charts/solid-queue-async-http-advantage.svg) / [Latency](../charts/solid-queue-async-http-latency.svg) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 7.04 jobs/s | fiber, c=25, proc=1, 141.79 MB | fiber, c=5, proc=6, 2789.42 ms | +13.2% across 9 cells | +28.0% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-ruby-llm-stream-latency.svg) |
| CPU | 18/18 | fiber, c=10, proc=6, 109.80 jobs/s | fiber, c=5, proc=1, 134.34 MB | fiber, c=10, proc=6, 2303.85 ms | +1.7% across 9 cells | +5.0% at c=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/solid-queue-cpu-grid.svg) / [Advantage](../charts/solid-queue-cpu-advantage.svg) / [Latency](../charts/solid-queue-cpu-latency.svg) |
| Net::HTTP | 18/18 | fiber, c=10, proc=6, 476.07 jobs/s | fiber, c=10, proc=1, 133.62 MB | fiber, c=10, proc=6, 1244.33 ms | +6.6% across 9 cells | +22.5% at c=50, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](../charts/solid-queue-http-grid.svg) / [Advantage](../charts/solid-queue-http-advantage.svg) / [Latency](../charts/solid-queue-http-latency.svg) |
| DB Queries | 18/18 | fiber, c=10, proc=6, 393.07 jobs/s | fiber, c=5, proc=1, 134.71 MB | fiber, c=10, proc=6, 748.48 ms | +8.8% across 9 cells | +13.9% at c=10, proc=6 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.svg) / [Advantage](../charts/solid-queue-db-queries-advantage.svg) / [Latency](../charts/solid-queue-db-queries-latency.svg) |
| DB Mixed | 18/18 | fiber, c=10, proc=6, 334.75 jobs/s | fiber, c=5, proc=1, 135.35 MB | fiber, c=10, proc=6, 899.22 ms | +2.4% across 9 cells | +13.1% at c=50, proc=1 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.svg) / [Advantage](../charts/solid-queue-db-mixed-advantage.svg) / [Latency](../charts/solid-queue-db-mixed-latency.svg) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 195.27 jobs/s | fiber, c=25, proc=1, 133.30 MB | fiber, c=10, proc=6, 1533.01 ms | +3.9% across 9 cells | +19.7% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-latency.svg) |
| DB Transaction Pool Pressure | 18/18 | fiber, c=10, proc=6, 194.45 jobs/s | fiber, c=10, proc=1, 135.35 MB | fiber, c=10, proc=6, 1526.38 ms | -32.5% across 9 cells | +1.7% at c=10, proc=6 | [CSV](db-transaction-pool-pressure-data.csv) / [JSON](db-transaction-pool-pressure-data.json) / [Grid](../charts/solid-queue-db-transaction-pool-pressure-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-pool-pressure-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-pool-pressure-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
