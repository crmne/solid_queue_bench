# Solid Queue Fiber Benchmarks

For these benchmarks, Solid Queue `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode, while `processes` is the number of worker OS processes. The headline comparison is limited to `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.

Across those headline workloads, Solid Queue fiber mode was usually faster than thread mode, but not by the same amount everywhere. Average fiber throughput deltas across paired cells were **5.71%** for `sleep`, **7.64%** for `async_http`, **12.66%** for `ruby_llm_stream`, and **1.12%** for `cpu`. Best observed fiber throughput deltas were **19.22%** (`sleep`), **22.17%** (`async_http`), **29.41%** (`ruby_llm_stream`), and **4.28%** (`cpu`). Fiber won **6/9** paired cells for `sleep`, **6/9** for `async_http`, **9/9** for `ruby_llm_stream`, and **5/9** for `cpu`. So the clearest gains are on cooperative wait, fiber-friendly I/O, and the streaming workload; the CPU-bound control shows only a small average gain.

Where the data supports it, fiber also tended to lower CPU and latency in the headline suite. Best observed CPU deltas favoring fiber were **22.20%** for `sleep`, **20.62%** for `async_http`, **9.24%** for `ruby_llm_stream`, and **3.79%** for `cpu`. Best observed latency deltas favoring fiber were **19.62%**, **15.47%**, **23.04%**, and **6.17%** respectively. Memory is more mixed at the absolute minimum-RSS point: the lowest RSS was fiber for `async_http`, `ruby_llm_stream`, and `cpu`, but thread for `sleep`. In the supplementary suite, thread also had the lowest absolute RSS point for blocking `http`. That means the data supports CPU and latency improvements more consistently than a blanket “fiber always uses less memory” claim.

The DB workloads answer a different set of questions. `db_queries` is the short DB-burst case: sequential reads plus writes with no external wait, and fiber won **9/9** paired cells there with an average throughput delta of **8.19%**. `db_mixed` is the read/API/write shape, combining DB reads, a delayed HTTP call, and DB writes; fiber still led on average, but more modestly, at **2.04%** across paired cells. `db_transaction` keeps reads and writes inside one transaction and matches the DB pool for both modes at `DB_POOL = concurrency + 5`, so it is the fairness check for runtime behavior when jobs hold connections for the whole transaction. There, fiber still averaged a **3.78%** throughput advantage across paired cells, with a best observed gain of **19.50%**, but that result should be read specifically as the matched-pool transaction comparison.

## What The Benchmarks Answer

- **Is Solid Queue fiber faster than Solid Queue thread?**  
  For the headline workloads, usually yes, especially on `sleep`, `async_http`, and `ruby_llm_stream`. On `cpu`, the gain is small on average.

- **What happens to memory, CPU, and latency?**  
  The data supports lower CPU and lower latency for fiber in the headline workloads. Memory is not a universal fiber win: some workloads had the lowest observed RSS in fiber mode, while `sleep` and supplementary blocking `http` had the lowest absolute RSS point in thread mode.

- **Do short DB bursts still work with the smaller shared fiber pool policy?**  
  `db_queries` suggests yes in this matrix: fiber won all **9/9** paired cells and averaged **8.19%** higher throughput.

- **How does mixed read/API/write work behave?**  
  `db_mixed` still favors fiber, but the margin is smaller: **2.04%** average throughput delta across paired cells.

- **What happens when jobs pin DB connections for a whole transaction?**  
  `db_transaction` is the benchmark that answers that fairly, because the DB pool is matched for both modes. In that matched-pool setup, fiber still led slightly on average.

- **How does Async::Job compare?**  
  Async::Job is not a mode-only comparison; it changes the backend to Redis. In the headline suite its best throughputs were higher than Solid Queue’s for `sleep` (**628.53** vs **509.61** jobs/s), `async_http` (**630.29** vs **500.44**), `ruby_llm_stream` (**16.68** vs **7.08**), and `cpu` (**123.66** vs **112.38**). That is useful context, but it is a backend comparison rather than a direct Solid Queue fiber-vs-thread result.

## Caveats

- These are results from the tested matrix, not proof that fiber wins at every concurrency, process count, or pool size.
- The headline and supplementary suites cap total concurrency at **60**, so they avoid turning the main comparison into a pool-exhaustion test.
- The stress suite should be read as a **current Solid Queue implementation/design failure-envelope test under high connection demand**, not as a fundamental thread-vs-fiber law. In stress, thread completed **1/10** planned cells for `sleep`, **1/10** for `async_http`, and **0/10** for `ruby_llm_stream`, while fiber completed **10/10** for each.
- Async::Job changes the backend, so it should not be presented as “Solid Queue but faster.”
- The harness uses aggressive queue polling, so these results reflect benchmark execution behavior under a low-latency configuration, not default production settings.
