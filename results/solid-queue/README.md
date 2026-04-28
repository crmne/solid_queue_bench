# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-28T01:16:07Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Same backend, different executor. Primary sweep tasks use matched DB pools for the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 18/18 | fiber, c=10, proc=6, 509.61 jobs/s | thread, c=5, proc=1, 133.70 MB | fiber, c=10, proc=6, 1184.38 ms | +5.7% across 9 cells | +19.2% at c=50, proc=1 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-sleep-grid.svg) / [Advantage](../charts/solid-queue-sleep-advantage.svg) / [Latency](../charts/solid-queue-sleep-latency.svg) |
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 500.44 jobs/s | fiber, c=10, proc=1, 135.30 MB | fiber, c=10, proc=6, 1186.51 ms | +7.6% across 9 cells | +22.2% at c=50, proc=1 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-async-http-grid.svg) / [Advantage](../charts/solid-queue-async-http-advantage.svg) / [Latency](../charts/solid-queue-async-http-latency.svg) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 7.08 jobs/s | fiber, c=10, proc=1, 141.38 MB | fiber, c=5, proc=6, 2759.11 ms | +12.7% across 9 cells | +29.4% at c=25, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-ruby-llm-stream-latency.svg) |
| CPU | 18/18 | fiber, c=10, proc=6, 112.38 jobs/s | fiber, c=5, proc=1, 135.57 MB | fiber, c=10, proc=6, 2262.08 ms | +1.1% across 9 cells | +4.3% at c=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/solid-queue-cpu-grid.svg) / [Advantage](../charts/solid-queue-cpu-advantage.svg) / [Latency](../charts/solid-queue-cpu-latency.svg) |
| Net::HTTP | 18/18 | fiber, c=10, proc=6, 499.00 jobs/s | thread, c=5, proc=1, 133.53 MB | fiber, c=10, proc=6, 1184.73 ms | +6.8% across 9 cells | +19.4% at c=50, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](../charts/solid-queue-http-grid.svg) / [Advantage](../charts/solid-queue-http-advantage.svg) / [Latency](../charts/solid-queue-http-latency.svg) |
| DB Queries | 18/18 | fiber, c=10, proc=6, 392.41 jobs/s | fiber, c=5, proc=1, 134.05 MB | fiber, c=10, proc=6, 756.48 ms | +8.2% across 9 cells | +17.0% at c=25, proc=2 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.svg) / [Advantage](../charts/solid-queue-db-queries-advantage.svg) / [Latency](../charts/solid-queue-db-queries-latency.svg) |
| DB Mixed | 18/18 | fiber, c=10, proc=6, 335.65 jobs/s | fiber, c=5, proc=1, 135.48 MB | fiber, c=10, proc=6, 886.57 ms | +2.0% across 9 cells | +12.0% at c=50, proc=1 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.svg) / [Advantage](../charts/solid-queue-db-mixed-advantage.svg) / [Latency](../charts/solid-queue-db-mixed-latency.svg) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 195.35 jobs/s | fiber, c=25, proc=1, 133.02 MB | fiber, c=10, proc=6, 1522.12 ms | +3.8% across 9 cells | +19.5% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
