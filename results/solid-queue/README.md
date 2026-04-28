# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-28T10:43:22Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Same backend, different executor. Primary sweep tasks use matched DB pools for the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 18/18 | fiber, c=10, proc=6, 500.50 jobs/s | fiber, c=25, proc=1, 129.50 MB | fiber, c=10, proc=6, 1192.99 ms | +7.4% across 9 cells | +15.9% at c=50, proc=1 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-sleep-grid.svg) / [Advantage](../charts/solid-queue-sleep-advantage.svg) / [Latency](../charts/solid-queue-sleep-latency.svg) |
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 492.82 jobs/s | fiber, c=25, proc=1, 130.88 MB | fiber, c=10, proc=6, 1197.94 ms | +9.5% across 9 cells | +25.5% at c=50, proc=1 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-async-http-grid.svg) / [Advantage](../charts/solid-queue-async-http-advantage.svg) / [Latency](../charts/solid-queue-async-http-latency.svg) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 7.01 jobs/s | fiber, c=25, proc=1, 135.72 MB | fiber, c=5, proc=6, 2767.07 ms | +11.9% across 9 cells | +21.8% at c=50, proc=1 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-ruby-llm-stream-latency.svg) |
| CPU | 18/18 | fiber, c=10, proc=6, 110.02 jobs/s | fiber, c=5, proc=1, 134.36 MB | fiber, c=10, proc=6, 2319.48 ms | +0.6% across 9 cells | +2.4% at c=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/solid-queue-cpu-grid.svg) / [Advantage](../charts/solid-queue-cpu-advantage.svg) / [Latency](../charts/solid-queue-cpu-latency.svg) |
| Net::HTTP | 18/18 | fiber, c=10, proc=6, 503.91 jobs/s | fiber, c=25, proc=1, 128.90 MB | fiber, c=10, proc=6, 1176.05 ms | +8.8% across 9 cells | +22.0% at c=50, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](../charts/solid-queue-http-grid.svg) / [Advantage](../charts/solid-queue-http-advantage.svg) / [Latency](../charts/solid-queue-http-latency.svg) |
| DB Queries | 18/18 | fiber, c=10, proc=6, 390.79 jobs/s | fiber, c=25, proc=1, 132.57 MB | fiber, c=10, proc=6, 742.66 ms | +12.6% across 9 cells | +23.9% at c=50, proc=1 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.svg) / [Advantage](../charts/solid-queue-db-queries-advantage.svg) / [Latency](../charts/solid-queue-db-queries-latency.svg) |
| DB Mixed | 18/18 | fiber, c=10, proc=6, 340.18 jobs/s | fiber, c=25, proc=1, 131.68 MB | fiber, c=10, proc=6, 873.87 ms | +6.9% across 9 cells | +21.2% at c=50, proc=1 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.svg) / [Advantage](../charts/solid-queue-db-mixed-advantage.svg) / [Latency](../charts/solid-queue-db-mixed-latency.svg) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 194.38 jobs/s | fiber, c=25, proc=1, 133.82 MB | fiber, c=10, proc=6, 1533.50 ms | +3.5% across 9 cells | +18.5% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
