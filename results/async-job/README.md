# Async::Job Results

Generated summary for the benchmark artifacts in this directory.

Latest dataset timestamp: `2026-04-04T12:59:04Z`

| Workload | Cells | Best Throughput | Lowest RSS | Lowest p50 Latency | Best Async Delta | Files |
|---|---|---|---|---|---|---|
| Sleep | 1/1 | async, cap=5, proc=1, 82.67 jobs/s | async, cap=5, proc=1, 152.54 MB | async, cap=5, proc=1, 6190.21 ms | n/a | [CSV](sleep-data.csv) / [JSON](sleep-data.json) / [Grid](sleep-grid.png) |

## Notes

- `Best Async Delta` is the strongest paired `async` vs `thread` throughput improvement within the same `(capacity, processes)` cell.
- `Cells` is `completed/planned`, so incomplete matrices are visible in the summaries.
- Async::Job datasets are single-mode, so paired async/thread deltas are `n/a` there.
- Headline workloads are `sleep`, `cpu`, `async_http`, and `ruby_llm_stream`.
