# Solid Queue Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-05T02:57:45Z`

Takeaway: Directionally expected result: `async` is a moderate win in the headline tests, with the clearest internal result on `ruby_llm_stream`. The main practical gain is keeping good performance without thread-sized DB pools.

| Workload | Tests | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Async::HTTP | 18/18 | async, cap=10, proc=6, 512.25 jobs/s | async, cap=10, proc=1, 116.66 MB | async, cap=10, proc=6, 1163.77 ms | +26.0% at cap=5, proc=2 | [CSV](async-http-data.csv) / [JSON](async-http-data.json) / [Grid](async-http-grid.png) / [Advantage](async-http-advantage.png) / [Latency](async-http-latency.png) |
| CPU | 18/18 | async, cap=10, proc=6, 112.47 jobs/s | thread, cap=5, proc=1, 120.25 MB | async, cap=10, proc=6, 2258.74 ms | +5.1% at cap=10, proc=6 | [CSV](cpu-data.csv) / [JSON](cpu-data.json) / [Grid](cpu-grid.png) / [Advantage](cpu-advantage.png) / [Latency](cpu-latency.png) |
| RubyLLM Stream | 18/18 | async, cap=5, proc=6, 6.68 jobs/s | async, cap=5, proc=1, 121.95 MB | async, cap=5, proc=6, 2913.14 ms | +20.2% at cap=10, proc=2 | [CSV](ruby-llm-stream-data.csv) / [JSON](ruby-llm-stream-data.json) / [Grid](ruby-llm-stream-grid.png) / [Advantage](ruby-llm-stream-advantage.png) / [Latency](ruby-llm-stream-latency.png) |
| Sleep | 18/18 | async, cap=10, proc=6, 507.19 jobs/s | async, cap=5, proc=1, 115.37 MB | async, cap=10, proc=6, 1169.05 ms | +27.2% at cap=10, proc=2 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` test.
- `Tests` is `completed/planned`, so missing or timed-out tests remain visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
