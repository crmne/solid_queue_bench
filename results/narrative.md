# Solid Queue Fiber Benchmark Summary

In the main Solid Queue runs, fiber mode produced the best-throughput result for every headline workload tested: Sleep, Net::HTTP, Async::HTTP, RubyLLM Stream, CPU, DB Queries, DB Mixed, DB Transaction, and DB Transaction Pool Pressure. This does not mean fiber was faster at every setting, but the reported best-throughput point and lowest-latency point both landed on fiber for each main workload.

The largest reported fiber-over-thread throughput deltas were strongest on I/O-shaped work: RubyLLM Stream `27.95275590551181%`, Net::HTTP `22.466539196940722%`, Async::HTTP `21.2047012732615%`, and Sleep `20.424266681914364%`. CPU work improved less: `4.981355770150104%`. DB Transaction Pool Pressure improved only `1.6944720464410756%` on throughput, which is important because that test is about pool sizing pressure, not just runtime fairness.

Memory and CPU results mostly also favored fiber in the main Solid Queue suite. Lowest RSS was fiber for every main workload except Sleep, where thread mode had the lowest RSS at `137156 KB`. Lowest CPU was fiber for every main Solid Queue workload. Lowest latency was fiber for every main Solid Queue workload, with the best-throughput configurations often also producing the lowest latency.

Async::Job had higher best throughput than Solid Queue fiber on the comparable workloads shown: Async::HTTP `653.93` vs `498.99` jobs/sec, CPU `120.18` vs `109.8`, RubyLLM Stream `16.87` vs `7.04`, and Sleep `635.94` vs `511.58`. It also showed lower best latencies on those workloads. However, Async::Job changes the backend, so these results compare backend choices, not Solid Queue thread mode vs Solid Queue fiber mode.

## What The Benchmarks Answer

### Solid Queue fiber vs Solid Queue thread

For the main Solid Queue matrix, each workload completed `18/18` tests. The best-throughput result was fiber in all cases:

| Workload | Best Solid Queue throughput | Best fiber delta |
|---|---:|---:|
| Sleep | `511.58` jobs/sec | `20.424266681914364%` |
| Net::HTTP | `476.07` jobs/sec | `22.466539196940722%` |
| Async::HTTP | `498.99` jobs/sec | `21.2047012732615%` |
| RubyLLM Stream | `7.04` jobs/sec | `27.95275590551181%` |
| CPU | `109.8` jobs/sec | `4.981355770150104%` |
| DB Queries | `393.07` jobs/sec | `13.903619345677946%` |
| DB Mixed | `334.75` jobs/sec | `13.100975008405241%` |
| DB Transaction, matched pool | `195.27` jobs/sec | `19.676360225140712%` |
| DB Transaction Pool Pressure, default pool | `194.45` jobs/sec | `1.6944720464410756%` |

The latency winners were also fiber across the main Solid Queue workloads. Examples:

| Workload | Lowest-latency mode | p50 | p95 | p99 |
|---|---|---:|---:|---:|
| Sleep | fiber | `1177.7 ms` | `1875.81 ms` | `1925.21 ms` |
| Net::HTTP | fiber | `1244.33 ms` | `2041.68 ms` | `2085.37 ms` |
| Async::HTTP | fiber | `1210.55 ms` | `1912.63 ms` | `1993.31 ms` |
| CPU | fiber | `2303.85 ms` | `4273.39 ms` | `4456.55 ms` |
| DB Queries | fiber | `748.48 ms` | `1226.66 ms` | `1250.77 ms` |
| DB Mixed | fiber | `899.22 ms` | `1457.1 ms` | `1479.75 ms` |
| DB Transaction | fiber | `1533.01 ms` | `2443.64 ms` | `2543.92 ms` |
| DB Transaction Pool Pressure | fiber | `1526.38 ms` | `2425.32 ms` | `2548.42 ms` |

### DB workload differences

The DB cases are not interchangeable:

- **DB Queries** is short DB-burst work: `10` reads, `2` writes, `duration_ms: 0`. Fiber’s best throughput was `393.07` jobs/sec, with lowest latency p50 `748.48 ms` and p95 `1226.66 ms`.
- **DB Mixed** adds `duration_ms: 50` around `10` reads and `2` writes. This represents read/API/write mixed work rather than only short DB bursts. Fiber’s best throughput was `334.75` jobs/sec, with lowest latency p50 `899.22 ms` and p95 `1457.1 ms`.
- **DB Transaction** uses `10` reads, `2` writes, and `duration_ms: 20` with a matched DB pool. This answers runtime fairness when the pool is sized to the workload. Fiber’s best throughput was `195.27` jobs/sec.
- **DB Transaction Pool Pressure** uses the same transaction payload with the default DB pool. This answers sizing pressure: what happens when transaction-holding work competes under the default pool. Fiber’s best throughput was `194.45` jobs/sec, but the best fiber throughput delta was only `1.6944720464410756%`.

### Memory and CPU

In the main Solid Queue runs, lowest CPU was fiber for every workload. Lowest RSS was fiber for every workload except Sleep, where thread mode had the lowest RSS at `137156 KB`.

For Solid Queue stress runs, the reported best-throughput, lowest-RSS, lowest-CPU, and lowest-latency modes were fiber for Async::HTTP, RubyLLM Stream, and Sleep. These stress runs completed `11/20` tests, so they should be read with more caution than the main `18/18` matrix.

### Async::Job comparison

Async::Job results were fiber-only and completed `9/9` tests for each shown workload. Compared with the best Solid Queue fiber results on the same headline workloads:

| Workload | Solid Queue fiber best throughput | Async::Job best throughput |
|---|---:|---:|
| Async::HTTP | `498.99` jobs/sec | `653.93` jobs/sec |
| CPU | `109.8` jobs/sec | `120.18` jobs/sec |
| RubyLLM Stream | `7.04` jobs/sec | `16.87` jobs/sec |
| Sleep | `511.58` jobs/sec | `635.94` jobs/sec |

Async::Job also had lower lowest-latency values on those workloads. But this is not a Solid Queue mode comparison: using Async::Job changes the job backend.

## Caveats

- The data shows best and lowest observed results from the tested matrix; it does not prove fiber wins at every concurrency, process count, or pool size.
- The main Solid Queue workloads completed `18/18` tests. The Solid Queue stress workloads completed `11/20` tests.
- DB pool configuration changes the meaning of transaction results. Matched-pool transaction results answer runtime fairness; default-pool transaction pressure results answer sizing pressure.
- Async::Job results are useful as a backend comparison, but they are not evidence that Solid Queue fiber and Async::Job are equivalent choices.
