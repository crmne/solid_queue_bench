# Solid Queue Fiber Benchmark Summary

Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative.

Best-throughput execution modes by headline workload: Async::HTTP: `fiber`; CPU: `fiber`; RubyLLM Stream: `fiber`; Sleep: `fiber`. The paired-cell win counts below describe how consistently each mode performs across the matrix.

CPU supplies a control for the I/O workloads. The supplementary DB workloads distinguish short queries, mixed I/O, and transactions. The primary Solid Queue suite uses matched DB pools so these rows stay focused on executor behavior.

Async::Job changes the backend to Redis. Treat its throughput table as a backend comparison; Solid Queue’s thread-versus-fiber results remain the direct executor comparison.

## What The Benchmarks Answer

### Headline workloads

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Best Solid Queue throughput |
|---|---:|---:|---:|---:|
| Sleep | 9/9 | +21.5% across 9 cells | +33.9% at c=10, proc=2 | fiber, 682.90 jobs/s |
| Async::HTTP | 9/9 | +20.7% across 9 cells | +28.6% at c=10, proc=2 | fiber, 665.42 jobs/s |
| RubyLLM Stream | 9/9 | +13.9% across 9 cells | +17.1% at c=25, proc=1 | fiber, 8.98 jobs/s |
| CPU | 4/9 | -0.1% across 9 cells | +4.2% at c=50, proc=1 | fiber, 154.84 jobs/s |

### DB workloads

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Interpretation |
|---|---:|---:|---:|---|
| DB Queries | 9/9 | +20.1% across 9 cells | +26.4% at c=25, proc=2 | Short DB bursts with no external wait. |
| DB Mixed | 5/9 | -0.9% across 9 cells | +11.1% at c=25, proc=1 | Read state, call the delay server, then write results. |
| DB Transaction | 9/9 | +9.0% across 9 cells | +16.5% at c=50, proc=1 | Matched-pool transaction run; fair executor comparison. |

### Stress

The stress suite is about completion, not about headline throughput. It removes the normal total-concurrency cap and shows the current Solid Queue failure envelope under high connection demand.

| Workload | Thread completed | Fiber completed |
|---|---:|---:|
| Sleep | 1/10 | 10/10 |
| Async::HTTP | 1/10 | 10/10 |
| RubyLLM Stream | 1/10 | 10/10 |

Read this as a current Solid Queue implementation result, especially around how connection demand scales at high thread counts. It should not be treated as a permanent or fundamental property of threads.

### Async::Job Comparison

| Workload | Async::Job best throughput | Solid Queue fiber best throughput |
|---|---:|---:|
| Sleep | 721.05 jobs/s | 682.90 jobs/s |
| Async::HTTP | 701.48 jobs/s | 665.42 jobs/s |
| RubyLLM Stream | 12.46 jobs/s | 8.98 jobs/s |
| CPU | 164.64 jobs/s | 154.84 jobs/s |

## Caveats

- The data shows best and lowest observed results from the tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.
- The public report excludes the old `db_transaction_pool_pressure` experiment; use the pool-policy suite for mismatched DB pool sizing.
- Primary Solid Queue comparisons should be read from matched-pool datasets.
- Async::Job changes the backend.
