# Solid Queue Results

Auto-generated from the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-24T12:51:06Z`
Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

Takeaway: `fiber` wins the majority of headline tests. The clearest result is `ruby_llm_stream`. The practical gain is good I/O performance without thread-sized DB pools.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Fiber Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 18/18 | fiber, c=10, proc=6, 512.25 jobs/s | fiber, c=10, proc=1, 116.66 MB | fiber, c=10, proc=6, 1163.77 ms | +26.0% at c=5, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) / [Advantage](async-http-advantage.png) / [Latency](async-http-latency.png) |
| CPU | 18/18 | fiber, c=10, proc=6, 112.47 jobs/s | thread, c=5, proc=1, 120.25 MB | fiber, c=10, proc=6, 2258.74 ms | +5.1% at c=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) / [Advantage](cpu-advantage.png) / [Latency](cpu-latency.png) |
| RubyLLM Stream | 18/18 | fiber, c=5, proc=6, 6.68 jobs/s | fiber, c=5, proc=1, 121.95 MB | fiber, c=5, proc=6, 2913.14 ms | +20.2% at c=10, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) / [Advantage](ruby-llm-stream-advantage.png) / [Latency](ruby-llm-stream-latency.png) |
| Sleep | 18/18 | fiber, c=10, proc=6, 507.19 jobs/s | fiber, c=5, proc=1, 115.37 MB | fiber, c=10, proc=6, 1169.05 ms | +27.2% at c=10, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |
| DB Mixed | 18/18 | fiber, c=10, proc=6, 336.69 jobs/s | fiber, c=10, proc=1, 116.34 MB | fiber, c=10, proc=6, 859.99 ms | +18.0% at c=25, proc=2 | [CSV](db-mixed-data.csv) / [JSON](db-mixed-data.json) / [Grid](db-mixed-grid.png) / [Advantage](db-mixed-advantage.png) / [Latency](db-mixed-latency.png) |
| DB Queries | 18/18 | fiber, c=10, proc=6, 386.43 jobs/s | fiber, c=10, proc=1, 116.36 MB | fiber, c=10, proc=6, 763.27 ms | +16.9% at c=25, proc=1 | [CSV](db-queries-data.csv) / [JSON](db-queries-data.json) / [Grid](db-queries-grid.png) / [Advantage](db-queries-advantage.png) / [Latency](db-queries-latency.png) |
| DB Transaction | 18/18 | fiber, c=10, proc=6, 198.07 jobs/s | fiber, c=25, proc=1, 115.85 MB | fiber, c=10, proc=6, 1498.53 ms | +24.6% at c=50, proc=1 | [CSV](db-transaction-data.csv) / [JSON](db-transaction-data.json) / [Grid](db-transaction-grid.png) / [Advantage](db-transaction-advantage.png) / [Latency](db-transaction-latency.png) |

## Notes

- `Best Fiber Delta` is the strongest paired `fiber` vs `thread` throughput improvement within the same `(concurrency, processes)` test.
- `Tests` is `completed/planned`, so missing or timed-out tests remain visible in the summaries.
- Async::Job datasets are single-mode, so paired fiber/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
