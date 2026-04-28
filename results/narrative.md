# Solid Queue Fiber Mode: What These Benchmarks Show

In Solid Queue, `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode, while `processes` is the number of worker OS processes. The primary Solid Queue comparisons use matched database pools for both modes: `DB_POOL = concurrency + 5` per worker process. That matters because these results are meant to answer executor/runtime fairness first, not pool-sizing policy.

Across the headline workloads, Solid Queue fiber is generally faster than Solid Queue thread for `sleep`, `async_http`, and `ruby_llm_stream`, and only marginally different for `cpu`. The average fiber throughput delta across paired cells is **7.41%** for `sleep`, **9.47%** for `async_http`, **11.93%** for `ruby_llm_stream`, and **0.63%** for `cpu`. The best observed fiber throughput delta is **15.92%** for `sleep`, **25.46%** for `async_http`, **21.82%** for `ruby_llm_stream`, and **2.37%** for `cpu`. Fiber wins all paired cells for `ruby_llm_stream`, wins 6/9 for `sleep`, 6/9 for `async_http`, and 6/9 for `cpu`.

On memory and latency, the matched-pool Solid Queue data generally favors fiber. The lowest observed RSS is fiber for all four headline workloads, and the best observed RSS delta reaches **100.0%** in each headline workload. Lowest observed latency is also fiber for all four headline workloads, with best observed latency deltas of **14.24%** for `sleep`, **20.35%** for `async_http`, **18.23%** for `ruby_llm_stream`, and **4.59%** for `cpu`. CPU use is more mixed: lowest observed CPU is fiber for `async_http`, `ruby_llm_stream`, and `cpu`, but thread is lowest for `sleep`. Even so, the best observed CPU delta still favors fiber in all four headline workloads.

The supplementary DB workloads separate three cases. `db_queries` is short DB burst work without external I/O; there fiber wins all paired cells, with **12.64%** average throughput gain and **23.92%** best gain. `db_mixed` is read/API/write work; fiber is ahead there too, with **6.87%** average and **21.24%** best throughput gain. `db_transaction` is the connection-pinning transaction case; fiber still has a **3.54%** average and **18.51%** best throughput gain in the matched-pool comparison, but only wins 4/9 paired cells, so the advantage is less consistent when jobs hold a DB connection for the whole transaction.

## What The Benchmarks Answer

- **Is Solid Queue fiber faster than Solid Queue thread for the same workload?**  
  For the headline suite with matched DB pools, usually yes for `sleep`, `async_http`, and `ruby_llm_stream`, and only slightly for `cpu`.

- **What do the headline results say about memory, CPU, and latency?**  
  With matched pools, the lowest observed RSS is fiber for all headline workloads, and the lowest observed latency is also fiber for all headline workloads. CPU also often favors fiber, but not universally: `sleep` has the lowest observed CPU in thread mode.

- **How should the DB workloads be read?**  
  - `db_queries`: short DB bursts, no external I/O.  
  - `db_mixed`: DB reads, delayed HTTP call, then DB writes; a read/API/write mix.  
  - `db_transaction`: DB reads and writes in one transaction; this pins the DB connection for the whole transaction and is the fair matched-pool transaction comparison.  
  In these matched-pool runs, fiber looks strongest on short DB bursts, still positive on read/API/write mixed work, and less consistent when connections stay pinned for the full transaction.

- **What about DB pool policy?**  
  The primary Solid Queue comparisons answer the executor/runtime question fairly only because the DB pool is matched for both modes. Mode-specific or mismatched DB pool runs, when present, answer a different operational question: whether a smaller shared fiber pool is workable for a given workload.

- **How does Async::Job compare?**  
  Async::Job is not just a mode change; it changes the backend to Redis. So its results are backend comparisons, not Solid Queue thread-vs-fiber comparisons. In the headline suite, its best throughput is higher than Solid Queue’s on `sleep` (**644.98** vs **500.5**), `async_http` (**652.96** vs **492.82**), `ruby_llm_stream` (**16.94** vs **7.01**), and `cpu` (**125.75** vs **110.02**). That may be useful if you are considering a backend change, but it does not isolate Solid Queue executor behavior.

- **What does the stress suite mean?**  
  The stress suite removes the capped main-matrix concurrency limit and uses the mode-specific pool policy unless overridden. It is best read as a current Solid Queue implementation/design failure-envelope test under high connection demand, not as a fundamental thread-vs-fiber law. In this dataset, thread completed only 1/10 planned cells for each stress workload, while fiber completed 10/10.

## Caveats

- The headline discussion here is limited to `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.
- These results are from the tested matrix on Ruby 4.0.2 and Solid Queue revision `305bf4018352e099019f9f24502a18ee4794e64e`; they do not prove fiber wins at every concurrency, process count, or pool size.
- The main Solid Queue comparison is intentionally capped at total concurrency `60` so it stays focused on executor behavior rather than turning into a pool-exhaustion test.
- Async::Job comparisons change the backend, so they should not be read as executor-only evidence.
- The harness uses aggressive queue polling, so this reflects low-latency benchmark settings rather than default production settings.
