# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-25T12:31:17Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Net::HTTP | 18/18 | thread, c=10, proc=6, 453.49 jobs/s | fiber, c=10, proc=1, 133.55 MB | fiber, c=10, proc=6, 1256.78 ms | -5.2% across 9 cells | -1.3% at c=10, proc=6 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](../charts/solid-queue-http-grid.svg) / [Advantage](../charts/solid-queue-http-advantage.svg) / [Latency](../charts/solid-queue-http-latency.svg) |
| DB Queries | 18/18 | thread, c=10, proc=6, 354.18 jobs/s | fiber, c=5, proc=1, 135.13 MB | thread, c=10, proc=6, 830.38 ms | -13.9% across 9 cells | -6.2% at c=10, proc=6 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.svg) / [Advantage](../charts/solid-queue-db-queries-advantage.svg) / [Latency](../charts/solid-queue-db-queries-latency.svg) |
| DB Mixed | 18/18 | thread, c=10, proc=6, 303.01 jobs/s | fiber, c=5, proc=1, 134.92 MB | thread, c=10, proc=6, 948.21 ms | -14.6% across 9 cells | -7.4% at c=10, proc=6 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.svg) / [Advantage](../charts/solid-queue-db-mixed-advantage.svg) / [Latency](../charts/solid-queue-db-mixed-latency.svg) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 194.22 jobs/s | fiber, c=50, proc=1, 134.45 MB | fiber, c=10, proc=6, 1540.00 ms | +3.3% across 9 cells | +16.6% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
