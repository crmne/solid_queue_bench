# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-10-06T20:58:10Z`

Dependencies: rails `8.1.4`, solid_queue `1.7.0`, ruby_llm `2.0.0`.

Same backend, different executor. Primary sweep tasks use matched DB pools for the direct Solid Queue thread-vs-fiber comparison.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta | Artifacts |
|---|---|---|---|---|---|---|---|
| Sleep | 18/18 | fiber, c=10, proc=6, 682.90 jobs/s | fiber, c=50, proc=1, 123.21 MB | fiber, c=10, proc=6, 909.95 ms | +21.5% across 9 cells | +33.9% at c=10, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](../charts/solid-queue-sleep-grid.svg) / [Advantage](../charts/solid-queue-sleep-advantage.svg) / [Latency](../charts/solid-queue-sleep-latency.svg) |
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 665.42 jobs/s | fiber, c=25, proc=1, 123.89 MB | fiber, c=10, proc=6, 900.20 ms | +20.7% across 9 cells | +28.6% at c=10, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](../charts/solid-queue-async-http-grid.svg) / [Advantage](../charts/solid-queue-async-http-advantage.svg) / [Latency](../charts/solid-queue-async-http-latency.svg) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 8.98 jobs/s | fiber, c=5, proc=1, 174.43 MB | fiber, c=5, proc=6, 2182.53 ms | +13.9% across 9 cells | +17.1% at c=25, proc=1 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](../charts/solid-queue-ruby-llm-stream-grid.svg) / [Advantage](../charts/solid-queue-ruby-llm-stream-advantage.svg) / [Latency](../charts/solid-queue-ruby-llm-stream-latency.svg) |
| CPU | 18/18 | fiber, c=5, proc=6, 154.84 jobs/s | fiber, c=50, proc=1, 124.69 MB | fiber, c=5, proc=6, 1690.92 ms | -0.1% across 9 cells | +4.2% at c=50, proc=1 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](../charts/solid-queue-cpu-grid.svg) / [Advantage](../charts/solid-queue-cpu-advantage.svg) / [Latency](../charts/solid-queue-cpu-latency.svg) |
| Net::HTTP | 18/18 | fiber, c=10, proc=6, 695.53 jobs/s | fiber, c=25, proc=1, 122.68 MB | fiber, c=10, proc=6, 890.35 ms | +23.1% across 9 cells | +35.8% at c=10, proc=1 | [CSV](http-data.csv) / [JSON](http-data.json) / [Grid](../charts/solid-queue-http-grid.svg) / [Advantage](../charts/solid-queue-http-advantage.svg) / [Latency](../charts/solid-queue-http-latency.svg) |
| DB Queries | 18/18 | fiber, c=5, proc=6, 574.77 jobs/s | fiber, c=50, proc=1, 123.35 MB | fiber, c=5, proc=6, 515.88 ms | +20.1% across 9 cells | +26.4% at c=25, proc=2 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](../charts/solid-queue-db-queries-grid.svg) / [Advantage](../charts/solid-queue-db-queries-advantage.svg) / [Latency](../charts/solid-queue-db-queries-latency.svg) |
| DB Mixed | 18/18 | thread, c=10, proc=6, 393.76 jobs/s | fiber, c=50, proc=1, 124.73 MB | thread, c=10, proc=6, 731.30 ms | -0.9% across 9 cells | +11.1% at c=25, proc=1 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](../charts/solid-queue-db-mixed-grid.svg) / [Advantage](../charts/solid-queue-db-mixed-advantage.svg) / [Latency](../charts/solid-queue-db-mixed-latency.svg) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 220.94 jobs/s | fiber, c=50, proc=1, 124.67 MB | fiber, c=10, proc=6, 1342.89 ms | +9.0% across 9 cells | +16.5% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](../charts/solid-queue-db-transaction-grid.svg) / [Advantage](../charts/solid-queue-db-transaction-advantage.svg) / [Latency](../charts/solid-queue-db-transaction-latency.svg) |

## Notes

- `Best Fiber Throughput Delta` compares `fiber` to `thread` in the same `(concurrency, processes)` cell.
- `Avg Fiber Throughput Delta` averages those same paired-cell throughput deltas.
- `Tests` is `completed/planned`, so failed or timed-out cells stay visible.
- Async::Job is single-mode, so paired fiber/thread deltas are `n/a` there.
