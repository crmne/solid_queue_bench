# Solid Queue Fiber Mode Benchmark Summary

Solid Queue fiber mode produced the best observed throughput for every headline Solid Queue workload in this dataset. The strongest consistency was on `DB Queries` and `RubyLLM Stream`, where fiber won throughput in 9/9 paired comparisons. It was also ahead in 6/9 pairs for `Async::HTTP`, `Net::HTTP`, `Sleep`, and `CPU`, and 5/9 for `DB Mixed`.

The transaction results are more mixed. With a matched DB pool, fiber still had the best observed throughput point for `DB Transaction` at 195.27 jobs/sec, but won only 4/9 paired throughput comparisons. Under default-pool transaction pressure, fiber’s best point was 194.45 jobs/sec, but it won only 1/9 paired comparisons. Treat the matched-pool result as the fairer runtime comparison; treat the default-pool result as evidence about DB pool sizing pressure.

Where the data supports it, fiber also had the lowest observed latency for all headline Solid Queue workloads. Lowest observed CPU was also fiber across the headline set. Lowest observed RSS was fiber for all headline workloads except `Sleep`, where thread had the lowest RSS at 137,156 KB.

Async::Job showed higher best throughput than Solid Queue on the overlapping workloads tested: `Async::HTTP`, `CPU`, `RubyLLM Stream`, and `Sleep`. But that comparison changes the backend, so it should not be read as “Solid Queue fiber mode versus Solid Queue thread mode.”

## What The Benchmarks Answer

- **Solid Queue fiber vs thread, headline throughput**
  - Fiber had the best observed throughput for all headline Solid Queue workloads.
  - Pairwise throughput wins varied:
    - `DB Queries`: 9/9
    - `RubyLLM Stream`: 9/9
    - `Async::HTTP`: 6/9
    - `Net::HTTP`: 6/9
    - `Sleep`: 6/9
    - `CPU`: 6/9
    - `DB Mixed`: 5/9
    - `DB Transaction`, matched pool: 4/9
    - `DB Transaction Pool Pressure`, default pool: 1/9

- **Memory, CPU, and latency**
  - Lowest observed latency was fiber for every headline Solid Queue workload.
  - Lowest observed CPU was fiber for every headline Solid Queue workload.
  - Lowest observed RSS was usually fiber, but not universally: `Sleep` had the lowest RSS in thread mode.
  - The data supports saying fiber often improved latency and CPU in these runs; it does not support saying fiber always reduces memory.

- **DB workload differences**
  - `DB Queries` is the short DB burst case: 10 reads, 2 writes, no added duration. Fiber won 9/9 throughput pairs, with best throughput 393.07 jobs/sec.
  - `DB Mixed` adds 50 ms duration to the 10-read/2-write shape, representing mixed read/API/write work. Fiber won 5/9 pairs, with best throughput 334.75 jobs/sec.
  - `DB Transaction` keeps the 10-read/2-write shape but holds work inside a 20 ms transaction. With matched pool sizing, fiber won 4/9 pairs and reached 195.27 jobs/sec.
  - `DB Transaction Pool Pressure` uses the default pool. Fiber won only 1/9 pairs and reached 194.45 jobs/sec. This is the sizing-pressure result, not the cleanest runtime fairness result.

- **Stress runs**
  - Stress tests used longer waits or higher concurrency and completed 11/20 tests per workload.
  - Fiber had the best observed throughput for the stress workloads:
    - `Async::HTTP`: 739.49 jobs/sec
    - `Sleep`: 807.53 jobs/sec
    - `RubyLLM Stream`: 8.86 jobs/sec
  - Each stress workload had only 1 paired throughput comparison, and fiber won that one pair in each case.

- **Async::Job comparison**
  - Async::Job best throughput exceeded Solid Queue’s best throughput on overlapping workloads:
    - `Async::HTTP`: 653.93 vs Solid Queue 498.99 jobs/sec
    - `CPU`: 120.18 vs Solid Queue 109.8 jobs/sec
    - `RubyLLM Stream`: 16.87 vs Solid Queue 7.04 jobs/sec
    - `Sleep`: 635.94 vs Solid Queue 511.58 jobs/sec
  - Async::Job also had lower observed latency on those overlapping workloads.
  - This is a backend comparison, not a Solid Queue thread-vs-fiber comparison.

## Caveats

- These results describe the tested workloads, concurrency levels, process counts, DB pool settings, and repeat count.
- “Best observed throughput” and “pairwise win rate” answer different questions. Fiber can have the best point while not winning most paired comparisons.
- Transaction benchmarks must be read with pool sizing in mind:
  - matched-pool results answer runtime fairness;
  - default-pool pressure results answer sizing pressure.
- Async::Job results are useful context, but they change the job backend and should not be attributed to Solid Queue fiber mode alone.
- Stress results are less complete than the headline runs: 11/20 tests completed for each listed stress workload.
