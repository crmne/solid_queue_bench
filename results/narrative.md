# Solid Queue Fiber Mode Benchmark Summary

Solid Queue fiber mode was the best-throughput mode for every main Solid Queue workload in this dataset. That does not mean it won every paired thread comparison: win rates ranged from **9/9** paired cells for DB Queries and RubyLLM Stream down to **1/9** for the default-pool DB transaction pressure case.

Across paired Solid Queue cells, the average fiber throughput delta was workload-dependent: small for CPU work, stronger for I/O-heavy and short DB-query work, and negative under default DB pool transaction pressure. The best fiber throughput delta ranged from **+1.69%** in the default-pool pressure case to **+27.95%** for RubyLLM Stream.

Memory, CPU, and latency mostly favored fiber in the best observed cells, but the memory result is not universal: the lowest RSS cell was fiber for all main Solid Queue workloads except Sleep, where thread had the lowest RSS. Lowest CPU and lowest latency were fiber for every main Solid Queue workload in the dataset.

Async::Job posted higher best throughput than Solid Queue fiber on the four workloads where it was tested, but that comparison changes the backend. Treat those numbers as **Async::Job vs Solid Queue**, not as another Solid Queue fiber-vs-thread result.

## What The Benchmarks Answer

### Solid Queue fiber vs thread throughput

| Workload | Fiber wins | Avg fiber throughput delta | Best fiber throughput delta | Best Solid Queue throughput |
|---|---:|---:|---:|---:|
| Async::HTTP | 6/9 | +6.97% | +21.20% | fiber, 498.99 jobs/s |
| CPU | 6/9 | +1.68% | +4.98% | fiber, 109.8 jobs/s |
| DB Mixed | 5/9 | +2.42% | +13.10% | fiber, 334.75 jobs/s |
| DB Queries | 9/9 | +8.80% | +13.90% | fiber, 393.07 jobs/s |
| DB Transaction, matched pool | 4/9 | +3.88% | +19.68% | fiber, 195.27 jobs/s |
| DB Transaction, default pool pressure | 1/9 | -32.49% | +1.69% | fiber, 194.45 jobs/s |
| Net::HTTP | 6/9 | +6.62% | +22.47% | fiber, 476.07 jobs/s |
| RubyLLM Stream | 9/9 | +13.18% | +27.95% | fiber, 7.04 jobs/s |
| Sleep | 6/9 | +5.93% | +20.42% | fiber, 511.58 jobs/s |

The headline result is that fiber can be faster than thread for Solid Queue, especially for I/O wait, streaming, and short DB-query workloads. The CPU workload shows a much smaller average gain. The default-pool transaction pressure result is the outlier: fiber still had the best single throughput cell, but averaged much worse across paired cells.

### DB workload differences

- **DB Queries**: short DB bursts, with `reads: 10`, `writes: 2`, and `duration_ms: 0`. Fiber won **9/9** paired cells, averaged **+8.80%**, and had a best fiber delta of **+13.90%**.
- **DB Mixed**: read/API/write mixed work, with `reads: 10`, `writes: 2`, and `duration_ms: 50`. Fiber won **5/9**, averaged **+2.42%**, and had a best fiber delta of **+13.10%**.
- **DB Transaction, matched pool**: transaction work with `reads: 10`, `writes: 2`, and `duration_ms: 20`, using matched DB pool sizing. This answers **runtime fairness**: with pool sizing adjusted to the concurrency shape, fiber averaged **+3.88%** and had a best fiber delta of **+19.68%**.
- **DB Transaction, default pool pressure**: same transaction payload, but with default DB pool sizing. This answers **sizing pressure**: fiber won only **1/9** paired cells and averaged **-32.49%**, which points to DB pool sizing as a limiting factor under this shape.

### Memory, CPU, and latency

- **Memory**: the lowest RSS cell was fiber for every main Solid Queue workload except Sleep. The lowest observed RSS values were generally around the high-130 MB range for these runs; RubyLLM Stream was higher at **145,196 KB**. Sleep’s lowest RSS was thread at **137,156 KB**.
- **CPU**: the lowest CPU cell was fiber for every main Solid Queue workload. This includes I/O-style workloads such as Sleep, Net::HTTP, Async::HTTP, and DB Mixed. In the default-pool pressure case, the lowest CPU was also fiber, but that workload’s throughput averaged much worse, so lower CPU there should not be read as better overall efficiency.
- **Latency**: the lowest-latency cell was fiber for every main Solid Queue workload. Best latency deltas favored fiber, including **+21.74%** for RubyLLM Stream, **+18.18%** for Sleep, **+17.69%** for DB Mixed, and **+15.37%** for Net::HTTP.

### Async::Job comparison

Async::Job was tested only in fiber mode and only on four workloads. Its best throughputs were:

| Workload | Async::Job best throughput | Solid Queue fiber best throughput |
|---|---:|---:|
| Async::HTTP | 653.93 jobs/s | 498.99 jobs/s |
| CPU | 120.18 jobs/s | 109.8 jobs/s |
| RubyLLM Stream | 16.87 jobs/s | 7.04 jobs/s |
| Sleep | 635.94 jobs/s | 511.58 jobs/s |

These results are useful if you are considering a backend change. They do not isolate fiber mode inside Solid Queue, because Async::Job changes the job backend.

## Caveats

- The main Solid Queue results completed **18/18** tests per workload; Async::Job completed **9/9** tests per workload.
- The Solid Queue stress runs completed **11/20** tests and had only **1** paired fiber/thread comparison per workload. In those limited paired cells, fiber won for Async::HTTP, RubyLLM Stream, and Sleep, with average/best deltas of **+6.41%**, **+7.82%**, and **+6.15%** respectively.
- The transaction results need to be read by pool mode: matched-pool results speak to runtime fairness, while default-pool pressure results speak to DB pool sizing pressure.
- Best-cell results show what happened at the best observed concurrency/process shape; they do not imply every configuration improved.
- Async::Job comparisons are backend comparisons, not Solid Queue thread-vs-fiber comparisons.
