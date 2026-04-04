# Solid Queue Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-04T12:46:40Z`

| Workload | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|
| Sleep | async, cap=5, proc=1, 65.71 jobs/s | async, cap=5, proc=1, 115.76 MB | async, cap=5, proc=1, 8067.30 ms | +36.9% at cap=5, proc=1 | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) / [Advantage](sleep-advantage.png) / [Latency](sleep-latency.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
