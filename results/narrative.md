# Solid Queue Fiber Benchmark Summary

Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative.

On the headline Solid Queue workloads, the best-throughput point landed on `fiber` in every checked-in row. That does not mean `fiber` wins every paired cell; it means the best observed point in this same-backend comparison favored `fiber` for `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.

The larger gains are on wait-heavy work. CPU is the control and stays much closer. The supplementary DB workloads also favor `fiber` at the best observed points in this dataset, and `db_transaction` is run with a matched pool so it stays an apples-to-apples executor comparison.

Async::Job is faster than Solid Queue fiber on the comparable headline workloads in this run, but it changes the backend to Redis. Treat that as a backend comparison, not evidence about Solid Queue `thread` vs `fiber`.

## What The Benchmarks Answer

### Headline workloads

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Best Solid Queue throughput |
|---|---:|---:|---:|---:|
| Sleep | 6/9 | +5.9% across 9 cells | +20.4% at c=50, proc=1 | fiber, 511.58 jobs/s |
| Async::HTTP | 6/9 | +7.0% across 9 cells | +21.2% at c=50, proc=1 | fiber, 498.99 jobs/s |
| RubyLLM Stream | 9/9 | +13.2% across 9 cells | +28.0% at c=25, proc=2 | fiber, 7.04 jobs/s |
| CPU | 6/9 | +1.7% across 9 cells | +5.0% at c=10, proc=6 | fiber, 109.80 jobs/s |

### DB workloads

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Interpretation |
|---|---:|---:|---:|---|
| DB Queries | 9/9 | +8.8% across 9 cells | +13.9% at c=10, proc=6 | Short DB bursts with no external wait. |
| DB Mixed | 5/9 | +2.4% across 9 cells | +13.1% at c=50, proc=1 | Read state, call the delay server, then write results. |
| DB Transaction | 4/9 | +3.9% across 9 cells | +19.7% at c=50, proc=1 | Matched-pool transaction run; fair executor comparison. |

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
| Sleep | 635.94 jobs/s | 511.58 jobs/s |
| Async::HTTP | 653.93 jobs/s | 498.99 jobs/s |
| RubyLLM Stream | 16.87 jobs/s | 7.04 jobs/s |
| CPU | 120.18 jobs/s | 109.80 jobs/s |

## Caveats

- The data shows best and lowest observed results from the tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.
- The public report excludes the old `db_transaction_pool_pressure` experiment because it is not an apples-to-apples executor comparison.
- `db_transaction` is the fair transaction comparison because the DB pool is matched for both modes.
- Async::Job changes the backend.
