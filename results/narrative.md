# Solid Queue Fiber Bench

## Executive Summary

These results compare Solid Queue `thread` and `fiber` execution modes on Ruby 4.0.2, using representative runs selected by median real `jobs_per_second`. In Solid Queue, `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode. `processes` is the number of worker OS processes.

From the supplied facts, the capped Solid Queue headline result rows for `sleep`, `async_http`, `ruby_llm_stream`, and `cpu` are not present, so this report cannot claim that Solid Queue fiber is generally faster or slower than Solid Queue thread for the capped headline suite. The supplied Solid Queue stress data does cover `sleep`, `async_http`, and `ruby_llm_stream`: fiber was much faster for stress `sleep` and stress `async_http`, but not for the one paired stress `ruby_llm_stream` cell. No paired Solid Queue `cpu` data is present here.

For the supplementary DB workloads, fiber is not automatically faster. On short DB bursts (`db_queries`) and read/API/write mixed work (`db_mixed`), thread mode had the best throughput and fiber was negative on average across paired cells. On matched-pool long transactions (`db_transaction`), fiber had a small average throughput advantage and the best overall throughput. This matters because `db_transaction` matches the DB pool for both modes, so it answers runtime fairness rather than “fiber got a smaller pool” or “thread got a larger pool.”

Async::Job results are useful context, but they change the backend to Async::Job + Redis. Treat those numbers as a backend comparison, not a Solid Queue mode comparison.

## What The Benchmarks Answer

### Solid Queue headline workloads

The public headline scope is limited to:

- `sleep`
- `async_http`
- `ruby_llm_stream`
- `cpu`

However, the supplied result payload includes Async::Job headline rows and Solid Queue stress rows, but not capped Solid Queue headline rows. Therefore:

| Workload | Solid Queue fiber vs thread answer from supplied facts |
|---|---|
| `sleep` | No capped headline paired result present. In stress, fiber averaged `+2482.46%` throughput across 10 paired cells; best fiber delta was `+10226.82%`. |
| `async_http` | No capped headline paired result present. In stress, fiber averaged `+1607.93%` throughput across 10 paired cells; best fiber delta was `+3754.55%`. |
| `ruby_llm_stream` | No capped headline paired result present. In stress, only 1 paired cell completed; fiber delta was `-30.87%`. Stress completion was thread `1/10` planned cells and fiber `10/10`. |
| `cpu` | No paired Solid Queue result present in the supplied facts. |

The stress suite should be read as a current Solid Queue implementation/design failure-envelope test under high connection demand, not as a fundamental thread-vs-fiber law.

### Supplementary DB workloads

The DB workloads answer different questions:

| Workload | Shape | Result |
|---|---|---|
| `db_queries` | Short DB bursts: sequential reads plus writes | Thread had best throughput: `354.18 jobs/s` vs best fiber `332.29 jobs/s`. Fiber averaged `-13.91%` across 9 paired cells; best fiber delta was `-6.18%`. |
| `db_mixed` | Read state, wait on API-like delay, then write result | Thread had best throughput: `303.01 jobs/s` vs best fiber `280.55 jobs/s`. Fiber averaged `-14.61%` across 9 paired cells; best fiber delta was `-7.41%`. |
| `db_transaction` | Reads and writes held in one transaction | Fiber had best throughput: `194.22 jobs/s`. Fiber averaged `+3.29%` across 9 paired cells; best fiber delta was `+16.61%`. |

For `db_transaction`, both modes use the matched Solid Queue thread-minimum DB pool policy: `DB_POOL = concurrency + 2`. That makes it the fair transaction executor comparison.

### Memory, CPU, and latency

Where the supplied data supports it:

- Lowest observed RSS was fiber for the supplied Solid Queue supplementary and stress rows.
- In the supplementary Solid Queue rows, lowest observed CPU was fiber for `db_queries`, `db_mixed`, `db_transaction`, and `http`.
- In the stress rows, lowest observed CPU was thread for stress `sleep` and stress `async_http`, and fiber for stress `ruby_llm_stream`.
- Latency was mixed:
  - `db_queries`: lowest latency was thread.
  - `db_mixed`: lowest latency was thread.
  - `db_transaction`: lowest latency was fiber.
  - `http`: lowest latency was fiber.
  - Stress `sleep` and stress `async_http`: lowest latency was fiber.
  - Stress `ruby_llm_stream`: lowest latency was fiber, but only one thread paired cell completed.

### Async::Job comparison

Async::Job headline best throughputs were:

| Workload | Best Async::Job throughput |
|---|---:|
| `sleep` | `635.94 jobs/s` |
| `async_http` | `653.93 jobs/s` |
| `ruby_llm_stream` | `16.87 jobs/s` |
| `cpu` | `120.18 jobs/s` |

These are not Solid Queue fiber-vs-thread deltas. Async::Job changes the backend, so these results compare a different queue backend and execution model, not just Solid Queue execution mode.

## Caveats

- The supplied facts do not include capped Solid Queue headline result rows, so this narrative does not make a capped headline Solid Queue fiber-vs-thread claim.
- The data shows best and lowest observed results from this tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.
- Async::Job changes the backend, so those numbers are backend comparisons rather than Solid Queue mode comparisons.
- `db_transaction` is the fair transaction comparison because the DB pool is matched for both modes.
- Stress results reflect the current Solid Queue implementation under high connection demand and should not be read as a permanent thread-vs-fiber law.
- The harness uses aggressive queue polling, so these numbers reflect execution behavior under a low-latency benchmark configuration, not default production settings.
