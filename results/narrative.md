# Solid Queue Fiber Bench Results

## Executive Summary

For the headline Solid Queue workloads (`sleep`, `async_http`, `ruby_llm_stream`, and `cpu`), fiber mode was usually faster than thread mode in this tested matrix, but not universally. Across the 36 paired headline cells, fiber averaged a **6.94% throughput advantage**. The best observed fiber throughput delta was **27.95%** on `ruby_llm_stream` at concurrency `25`, `2` processes.

The strongest headline result was `ruby_llm_stream`: fiber won **9/9** paired cells, averaged **13.18%** higher throughput, and had a best paired throughput delta of **27.95%**. `sleep` and `async_http` each won **6/9** paired cells, with average fiber deltas of **5.93%** and **6.97%**. `cpu` also won **6/9**, but the average delta was small: **1.68%**, with a best delta of **4.98%**.

The resource and latency results point in the same general direction for the headline suite, with limits. Lowest observed CPU was fiber for all four headline workloads. Lowest observed latency was also fiber for all four. Lowest observed RSS was fiber for `async_http`, `ruby_llm_stream`, and `cpu`, but `sleep` had its lowest observed RSS in thread mode. The data shows best and lowest observed results from this matrix, not a guarantee that fiber minimizes memory, CPU, or latency at every setting.

Async::Job was faster than Solid Queue fiber in the headline best-throughput cells, but that comparison changes the backend to Async::Job + Redis. It should be read as a backend comparison, not as a Solid Queue thread-vs-fiber mode comparison.

## What The Benchmarks Answer

### Is Solid Queue fiber faster than Solid Queue thread?

In the capped headline Solid Queue suite, yes on average, but not in every paired cell.

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Best Solid Queue fiber throughput |
|---|---:|---:|---:|---:|
| `sleep` | 6/9 | 5.93% | 20.42% at concurrency `50`, `1` process | 511.58 jobs/s |
| `async_http` | 6/9 | 6.97% | 21.20% at concurrency `50`, `1` process | 498.99 jobs/s |
| `ruby_llm_stream` | 9/9 | 13.18% | 27.95% at concurrency `25`, `2` processes | 7.04 jobs/s |
| `cpu` | 6/9 | 1.68% | 4.98% at concurrency `10`, `6` processes | 109.8 jobs/s |

Across those paired headline cells, the average fiber throughput delta was **6.94%**.

### What happens to memory, CPU, and latency?

For the headline workloads:

- Lowest observed CPU was fiber for all four headline workloads:
  - `sleep`: 36.5% avg CPU
  - `async_http`: 37.9% avg CPU
  - `ruby_llm_stream`: 86.6% avg CPU
  - `cpu`: 95.2% avg CPU

- Lowest observed latency was fiber for all four headline workloads:
  - `sleep`: p50 1177.7 ms, p95 1875.81 ms
  - `async_http`: p50 1210.55 ms, p95 1912.63 ms
  - `ruby_llm_stream`: p50 2789.42 ms, p95 2835.35 ms
  - `cpu`: p50 2303.85 ms, p95 4273.39 ms

- Lowest observed RSS was mixed:
  - Fiber: `async_http` 138388 KB, `ruby_llm_stream` 145196 KB, `cpu` 137568 KB
  - Thread: `sleep` 137156 KB

The benchmark summary also records a best paired RSS delta of `100.0` for fiber on each headline workload, but the lowest-RSS result for `sleep` was thread mode, so this should not be read as “fiber always uses less memory.”

### How do the DB workloads differ?

The supplementary DB workloads test different shapes:

- `db_queries`: short DB bursts — sequential reads plus writes, with no external I/O delay.
  - Fiber won **9/9** paired cells.
  - Average fiber throughput delta: **8.80%**.
  - Best fiber throughput delta: **13.90%**.

- `db_mixed`: read/API/write shape — DB reads, a delayed HTTP call, then DB writes.
  - Fiber won **5/9** paired cells.
  - Average fiber throughput delta: **2.42%**.
  - Best fiber throughput delta: **13.10%**.

- `db_transaction`: long transaction shape — DB reads and writes inside one transaction.
  - Fiber won **4/9** paired cells.
  - Average fiber throughput delta: **3.88%**.
  - Best fiber throughput delta: **19.68%**.
  - This is the fair transaction runtime comparison because the DB pool is matched for both modes.

### How does Async::Job compare?

Async::Job uses fiber execution with a Redis-backed backend, so it is not a Solid Queue mode comparison.

Best headline throughputs:

| Workload | Solid Queue fiber best | Async::Job best |
|---|---:|---:|
| `sleep` | 511.58 jobs/s | 635.94 jobs/s |
| `async_http` | 498.99 jobs/s | 653.93 jobs/s |
| `ruby_llm_stream` | 7.04 jobs/s | 16.87 jobs/s |
| `cpu` | 109.8 jobs/s | 120.18 jobs/s |

These results show what happened when the backend changed too.

### What does the stress suite show?

The stress suite removes the capped total concurrency used by the main comparison. It is best read as a current Solid Queue implementation/design failure-envelope test under high connection demand, not as a fundamental thread-vs-fiber law.

In the stress suite, thread mode completed **1/10** planned cells for each of `sleep`, `async_http`, and `ruby_llm_stream`; fiber mode completed **10/10** for each.

## Caveats

- Results are from April 24–25, 2026, using Solid Queue revision `305bf4018352e099019f9f24502a18ee4794e64e`.
- The data shows best and lowest observed results from this tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.
- `jobs_per_second` counts successful jobs only.
- Latency percentiles are from successful jobs only.
- Async::Job changes the backend, so those numbers are a backend comparison rather than a Solid Queue mode comparison.
- `db_transaction` is the fair transaction comparison because the DB pool is matched for both modes.
- Stress results reflect the current Solid Queue implementation under high connection demand and should not be read as a permanent thread-vs-fiber law.
- The harness uses aggressive queue polling, so these numbers reflect execution behavior under a low-latency benchmark configuration, not default production settings.
