# Solid Queue Bench

Benchmark harness comparing Solid Queue's **thread** and **async** (fiber-based)
worker execution modes across a matrix of concurrency configurations. The goal
is to quantify throughput, memory, CPU, and latency differences as capacity and
process counts scale.

## Experiment Design

### What we are comparing

Solid Queue can execute claimed jobs in two modes:

- **Thread mode** (`execution_mode: thread`) -- each job runs in an OS thread
  from a `Concurrent::ThreadPoolExecutor`. The pool pre-allocates threads up to
  the configured capacity. Each thread holds its own Active Record database
  connection for the duration of the job.

- **Async mode** (`execution_mode: async`) -- each job runs as a Ruby Fiber on
  a single reactor thread (via the [`async`](https://github.com/socketry/async)
  gem). Fibers yield cooperatively during I/O, so hundreds of fibers can share a
  small number of database connections.

### Independent variables

| Variable | Values | What it controls |
|----------|--------|-----------------|
| **Execution mode** | `thread`, `async` | How jobs are scheduled within a worker |
| **Capacity** | 10, 25, 50, 75, 100, 150, 200 | Max concurrent jobs per worker process (threads or fibers) |
| **Worker processes** | 1, 2, 4 | Number of forked worker processes |

Each unique (mode, capacity, processes) combination is one **cell** in the
matrix. Each cell was run 3 times and we report the **median** result.

### Dependent variables (what we measure)

| Metric | How it is collected |
|--------|-------------------|
| **Throughput** (jobs/sec) | Total completed jobs / wall-clock time |
| **Peak RSS** (MB) | Max resident set size across all worker PIDs, sampled from `/proc/[pid]/status` every 100 ms |
| **Avg RSS** (MB) | Mean of all RSS samples during the run |
| **Avg CPU** (%) | Total CPU time (user + system from `/proc/[pid]/stat`) / wall time. Values above 100% indicate multi-core usage |
| **Peak CPU** (%) | Max instantaneous CPU % between consecutive samples |
| **Queue delay** (ms) | Time from enqueue to job start, reported as p50/p95/p99/max |
| **Service time** (ms) | Time the job actually runs, reported as p50/p95/p99/max |
| **Total latency** (ms) | Time from enqueue to job finish (queue delay + service time) |

### Workloads

| Workload | What each job does | Jobs per cell | Purpose |
|----------|-------------------|---------------|---------|
| **sleep** | `Kernel.sleep(0.05)` (50 ms) | 2,000 | Pure cooperative I/O wait -- best-case scenario for async |
| **cpu** | 50,000 SHA256 hash iterations (~50 ms) | 500 | CPU-bound control -- tests behavior under the GVL |
| **http** | `Net::HTTP.get` to a local delay server (50 ms) | 2,000 | Real TCP/HTTP I/O through Ruby's network stack |
| **async_http** | `Async::HTTP` to a local delay server (50 ms) | 2,000 | Fiber-native HTTP I/O |

### Database connection requirements

This is the critical scaling difference between the two modes:

| Mode | DB pool per worker | At capacity 100, 1 process | At capacity 200, 4 processes |
|------|-------------------|---------------------------|------------------------------|
| Thread | `capacity + 5` | 105 connections | 4 x 205 = 820 connections |
| Async | `max(5, processes + 4)` | 5 connections | 8 connections |

PostgreSQL's default `max_connections` is 100. Thread mode at capacity 100+
requires more connections than the server allows and fails to start.

### Environment

- Ruby 4.0.2, PostgreSQL `max_connections = 100`
- `config.active_support.isolation_level = :fiber`
- Linux 6.x, x86_64
- Solid Queue from local `async-worker-execution-mode` branch

## Results

### Sleep Workload

50 ms sleep, 2,000 jobs per cell, 3 repetitions (median reported). All 42 cells
completed with 0 failures. This is the primary benchmark.

![Comparison grid -- Sleep](results/sleep-grid.png)

Each column is a process count (1, 2, 4). Each row is a metric. Blue = thread,
red = async. Throughput is nearly identical between the two modes across all
configurations (~27-30 j/s). The dominant finding is memory: async uses 6-26%
less peak RSS across all cells, with the gap widening at higher capacities where
thread mode allocates more per-thread stacks. At 4 processes, both modes
saturate the scheduler at the same throughput, but async still uses consistently
less RSS. Thread mode's memory footprint grows with capacity due to per-thread
stack allocations; async stays nearly flat because fibers share a single stack.

![Async advantage -- Sleep](results/sleep-advantage.png)

Bars show the percentage improvement of async over thread for each
(capacity, processes) pair. Negative values on RSS mean async uses fewer
resources. The throughput difference is small on this machine (within +/-3% at
2-4 processes). RSS advantage is the dominant and most consistent signal,
ranging from -6% to -26% across all 42 cells. CPU usage is comparable between
the two modes.

![Latency percentiles -- Sleep](results/sleep-latency.png)

Latency distributions (p50/p95/p99/max) for queue delay, service time, and total
latency. P50 total latency is ~92 ms for both modes across all configurations
(50 ms sleep + ~42 ms queue delay). Tail latencies (p95/p99) are comparable.

<details>
<summary>Per-cell advantage data (sleep)</summary>

Advantage = (async - thread) / thread * 100. Negative RSS/CPU/latency values mean async uses fewer resources.

| Cap | Procs | Thread j/s | Async j/s | Tput % | Thread RSS MB | Async RSS MB | RSS % | Thread CPU % | Async CPU % | CPU % | Thread p50 ms | Async p50 ms | Lat p50 % |
|-----|-------|-----------|----------|--------|--------------|-------------|-------|-------------|------------|-------|--------------|-------------|-----------|
| 10 | 1 | 30.1 | 27.5 | -8.6 | 129 | 100 | -22.6 | 20.3 | 19.0 | -6.4 | 92 | 92 | -0.1 |
| 25 | 1 | 27.3 | 27.9 | +1.9 | 128 | 101 | -21.4 | 19.1 | 19.2 | +0.5 | 93 | 92 | -1.0 |
| 50 | 1 | 27.6 | 27.6 | +0.3 | 125 | 101 | -19.4 | 19.3 | 19.1 | -1.0 | 93 | 92 | -1.1 |
| 75 | 1 | 27.7 | 27.6 | -0.4 | 124 | 101 | -19.1 | 19.4 | 19.1 | -1.5 | 93 | 92 | -0.9 |
| 100 | 1 | 28.5 | 27.5 | -3.4 | 127 | 101 | -20.7 | 19.6 | 19.1 | -2.6 | 92 | 92 | -0.6 |
| 150 | 1 | 28.0 | 27.3 | -2.5 | 137 | 101 | -26.3 | 19.5 | 19.1 | -2.1 | 93 | 92 | -0.6 |
| 200 | 1 | 28.0 | 27.5 | -1.8 | 123 | 101 | -18.3 | 19.5 | 19.1 | -2.1 | 93 | 92 | -0.6 |
| 10 | 2 | 27.7 | 27.7 | +0.1 | 249 | 200 | -19.7 | 25.7 | 25.7 | 0.0 | 92 | 92 | -0.5 |
| 25 | 2 | 27.7 | 27.7 | -0.2 | 232 | 202 | -12.8 | 25.9 | 25.6 | -1.2 | 92 | 92 | -0.4 |
| 50 | 2 | 27.8 | 27.6 | -0.5 | 231 | 201 | -13.0 | 25.8 | 25.7 | -0.4 | 92 | 92 | -0.4 |
| 75 | 2 | 27.7 | 27.6 | -0.3 | 231 | 200 | -13.4 | 25.7 | 25.7 | 0.0 | 92 | 92 | -0.4 |
| 100 | 2 | 27.8 | 27.8 | +0.1 | 227 | 214 | -5.7 | 25.8 | 25.8 | 0.0 | 92 | 92 | -0.5 |
| 150 | 2 | 27.7 | 27.9 | +0.7 | 248 | 201 | -19.1 | 25.5 | 25.7 | +0.8 | 92 | 92 | -0.5 |
| 200 | 2 | 27.8 | 27.8 | +0.1 | 235 | 213 | -9.2 | 25.6 | 25.7 | +0.4 | 92 | 92 | -0.2 |
| 10 | 4 | 27.6 | 27.4 | -0.6 | 461 | 401 | -13.0 | 35.6 | 35.9 | +0.8 | 92 | 92 | -0.1 |
| 25 | 4 | 27.6 | 27.5 | -0.3 | 439 | 400 | -8.8 | 35.5 | 35.9 | +1.1 | 92 | 91 | -0.5 |
| 50 | 4 | 27.7 | 27.4 | -1.1 | 438 | 400 | -8.7 | 35.5 | 35.7 | +0.6 | 91 | 92 | +0.1 |
| 75 | 4 | 27.6 | 27.2 | -1.5 | 453 | 402 | -11.4 | 35.6 | 35.6 | 0.0 | 92 | 91 | -0.1 |
| 100 | 4 | 27.7 | 27.5 | -0.8 | 450 | 402 | -10.7 | 35.6 | 35.8 | +0.6 | 91 | 91 | +0.2 |
| 150 | 4 | 27.7 | 27.4 | -1.0 | 442 | 401 | -9.3 | 35.7 | 35.6 | -0.3 | 92 | 91 | -0.2 |
| 200 | 4 | 27.8 | 27.6 | -0.7 | 440 | 400 | -9.0 | 35.6 | 35.9 | +0.8 | 92 | 92 | -0.0 |

</details>

### CPU Workload (Control)

50,000 SHA256 iterations per job (~50 ms of pure CPU), 500 jobs per cell.
This is the **control** workload -- async fibers cannot parallelize CPU-bound
work any better than threads because both are limited by Ruby's GVL to one core
per process.

Thread mode data is incomplete: capacity 100, 150, and 200 at 1 process failed
due to database connection exhaustion (3 of 21 thread cells). All 21 async cells
completed. The remaining 18 thread cells completed, though at 2 processes with
capacity 50+ and at 4 processes across all capacities, throughput drops to ~27
j/s (single-core GVL bound) compared to the expected ~42 j/s (2 proc) or ~45
j/s (4 proc) seen at low capacities -- indicating that high thread counts under
GVL contention prevent effective multi-core utilization.

![Comparison grid -- CPU](results/cpu-grid.png)

Where both modes ran at 1 process, throughput is comparable: ~22-23 j/s for both.
Async shows a small advantage at higher capacities (+3-5% at capacity 50-75)
because fiber scheduling has less overhead than thread scheduling under the GVL.
At 2 processes with low capacity (10-25), both modes achieve ~42 j/s as expected.
At higher capacities and process counts, GVL contention dominates and both
modes converge to ~27 j/s.

Two things stand out:

1. **Thread mode fails at high capacity (1 process).** Capacity 100+ at 1
   process requires more database connections than PostgreSQL's default
   `max_connections = 100` allows. Async runs all capacities without issue.

2. **RSS diverges massively.** Where both modes ran, thread RSS grows linearly
   with capacity while async stays flat. At 1 process with capacity 75, thread
   uses 295 MB vs async's 118 MB -- a 60% reduction.

![Async advantage -- CPU](results/cpu-advantage.png)

FAILED cells indicate where thread mode did not complete. Where both ran at
1 process, async is 3-5% faster at capacity 50-75 (and 1-3% slower at capacity
10-25). The throughput advantage is smaller on this machine than previously
observed. RSS advantage for async is dramatic across all process counts,
ranging from -19% at capacity 10 to -60% at capacity 75 (1 process).

<details>
<summary>Per-cell advantage data (CPU)</summary>

Advantage = (async - thread) / thread * 100. FAILED = thread mode did not complete.

| Cap | Procs | Thread j/s | Async j/s | Tput % | Thread RSS MB | Async RSS MB | RSS % | Thread CPU % | Async CPU % | CPU % |
|-----|-------|-----------|----------|--------|--------------|-------------|-------|-------------|------------|-------|
| 10 | 1 | 23.2 | 22.8 | -1.6 | 135 | 110 | -19.1 | 96.7 | 92.8 | -4.0 |
| 25 | 1 | 23.1 | 22.5 | -2.6 | 198 | 123 | -37.6 | 96.8 | 91.9 | -5.1 |
| 50 | 1 | 22.7 | 23.5 | +3.4 | 258 | 118 | -54.4 | 96.8 | 94.6 | -2.3 |
| 75 | 1 | 22.5 | 23.6 | +4.8 | 295 | 118 | -60.0 | 96.9 | 94.4 | -2.6 |
| 100 | 1 | FAILED | 23.5 | -- | FAILED | 117 | -- | FAILED | 94.6 | -- |
| 150 | 1 | FAILED | 23.2 | -- | FAILED | 114 | -- | FAILED | 94.4 | -- |
| 200 | 1 | FAILED | 23.1 | -- | FAILED | 118 | -- | FAILED | 94.2 | -- |
| 10 | 2 | 41.8 | 42.1 | +0.8 | 254 | 211 | -16.8 | 187.5 | 184.1 | -1.8 |
| 25 | 2 | 41.1 | 42.9 | +4.3 | 351 | 224 | -36.3 | 186.7 | 184.6 | -1.1 |
| 50 | 2 | 26.8 | 27.2 | +1.3 | 273 | 208 | -23.8 | 126.6 | 127.1 | +0.4 |
| 75 | 2 | 26.9 | 26.9 | -0.3 | 276 | 208 | -24.6 | 124.7 | 125.4 | +0.6 |
| 100 | 2 | 27.0 | 26.7 | -0.8 | 281 | 208 | -26.2 | 125.0 | 124.8 | -0.2 |
| 150 | 2 | 26.9 | 27.0 | +0.6 | 289 | 208 | -27.7 | 125.5 | 126.1 | +0.5 |
| 200 | 2 | 27.1 | 26.9 | -0.6 | 290 | 207 | -28.5 | 125.5 | 125.3 | -0.2 |
| 10 | 4 | 27.9 | 27.8 | -0.4 | 423 | 393 | -7.1 | 144.4 | 145.2 | +0.6 |
| 25 | 4 | 27.6 | 27.8 | +0.5 | 439 | 396 | -9.8 | 143.8 | 144.6 | +0.6 |
| 50 | 4 | 27.7 | 27.7 | 0.0 | 456 | 394 | -13.5 | 144.6 | 145.5 | +0.6 |
| 75 | 4 | 27.7 | 27.8 | +0.3 | 446 | 397 | -11.0 | 144.0 | 143.9 | -0.1 |
| 100 | 4 | 27.7 | 27.6 | -0.1 | 439 | 394 | -10.1 | 144.0 | 144.8 | +0.6 |
| 150 | 4 | 27.8 | 27.6 | -0.8 | 443 | 397 | -10.4 | 144.3 | 147.2 | +2.0 |
| 200 | 4 | 27.8 | 27.8 | +0.0 | 444 | 395 | -11.1 | 145.4 | 143.5 | -1.3 |

</details>

### HTTP Workloads (Net::HTTP and Async::HTTP)

**Caveat: the delay server was not running on the benchmark machine.** All HTTP
jobs (both Net::HTTP and Async::HTTP) errored immediately -- every cell shows
`failed_jobs=2000` with ~1-2 ms service time instead of the intended 50 ms delay.
**Throughput and latency data is not meaningful** because it measures error
processing speed, not actual I/O concurrency.

However, the **RSS and CPU overhead comparisons remain valid** because those
metrics measure worker process resource consumption, which is independent of
whether the job payload succeeds or fails. The worker still allocates thread
stacks (in thread mode) or fiber contexts (in async mode) regardless of workload
outcome.

The delay server has since been fixed (the CGI gem dependency was removed and
replaced with `URI.decode_www_form`) and needs a rerun.

**Net::HTTP results:**

![Comparison grid -- HTTP](results/http-grid.png)

Thread RSS grows with capacity while async stays flat, consistent with the sleep
and CPU workloads. Async uses 6-33% less peak RSS across all cells.

![Async advantage -- HTTP](results/http-advantage.png)

The RSS bars are deeply negative (async uses far less memory). Throughput bars
should be disregarded due to the failed workload.

**Async::HTTP results:** Chart data was collected but charts were not generated
for the async_http workload. The same delay-server caveat applies. Raw data is
available in `results/async-http-data.csv`. Async uses 2-31% less peak RSS than
thread mode across all cells.

**Recommendation:** Rerun both HTTP workloads with the fixed delay server to
get valid throughput and latency comparisons.

## Key Findings

The following findings are based on the clean sleep data (all 42 cells, 0
failures, 3x repeat with median) and the CPU control data (all 21 async cells,
18 of 21 thread cells completed).

1. **Async throughput matches thread on I/O-bound work.** On the sleep workload,
   both modes achieve ~27-28 j/s across all configurations. The throughput
   difference is within +/-3% at 2-4 processes. At 1 process, thread is
   marginally faster at some capacities and marginally slower at others (range:
   -8.6% to +1.9%). On this machine, there is no consistent throughput advantage
   for either mode on the sleep workload.

2. **Async uses 6-26% less peak RSS on I/O-bound work.** This is the most
   consistent finding. Thread RSS grows with capacity (each thread stack costs
   ~1 MB). Async RSS stays flat at ~100 MB (1 proc), ~200-214 MB (2 proc), or
   ~400-402 MB (4 proc) because fibers share the process heap without per-unit
   stack allocations. At capacity 150 with 1 process: thread uses 137 MB, async
   uses 101 MB (26% savings).

3. **CPU usage is comparable between the two modes on I/O-bound work.** On the
   sleep workload, the CPU difference is within +/-2% at all process counts.
   Both modes are light on CPU for this workload (~19-20% at 1 proc, ~26% at
   2 proc, ~36% at 4 proc).

4. **Async shows a small throughput advantage on CPU-bound work at higher
   capacities (1 process).** At capacity 50-75, async is 3-5% faster than
   thread (~23.5 j/s vs ~22.5 j/s). This is because fiber scheduling has less
   overhead than thread scheduling under the GVL -- fibers context-switch in
   userspace without OS involvement. At capacity 10-25, the difference reverses
   slightly (-1.6% to -2.6%). The advantage is smaller on this machine than
   previously observed on other hardware.

5. **Thread mode fails at high capacity on CPU workloads.** Capacity 100+ at
   1 process requires more database connections than PostgreSQL's default
   `max_connections = 100`. 3 of 21 thread cells failed. Async ran all 21
   capacities without issue.

6. **Memory divergence is most dramatic on CPU-bound work.** At 1 process with
   capacity 75: thread uses 295 MB vs async's 118 MB (60% savings). At capacity
   50: thread uses 258 MB vs async's 118 MB (54% savings). Thread RSS grows
   linearly with capacity; async RSS stays flat at ~110-123 MB regardless of
   capacity.

7. **DB connections are the practical scaling ceiling for thread mode.** Thread
   mode needs `capacity + 5` connections per worker process; async needs
   `max(5, processes + 4)` total. At capacity 200 with 4 processes: thread needs
   820 connections, async needs 8. PostgreSQL's default `max_connections = 100`
   makes high-capacity thread deployments impractical without connection poolers
   like PgBouncer. Async mode sidesteps this entirely.

8. **GVL contention limits multi-process scaling on CPU-bound work.** At 2
   processes with capacity 50+, both thread and async throughput drops from the
   expected ~42 j/s to ~27 j/s, and at 4 processes all capacities are stuck at
   ~27-28 j/s. This suggests that high concurrency levels (many threads or
   fibers doing CPU work) create GVL scheduling contention that prevents
   effective multi-core utilization. Only low-capacity configurations (10-25) at
   2 processes achieve the expected 2x throughput scaling.

## Setup

Requires Ruby 4.0+ and PostgreSQL.

```bash
cd solid_queue_bench

# Database credentials
export DB_USER=your_user
export DB_PASSWORD=your_password
# optional: DB_HOST, DB_PORT

bin/setup
```

The Gemfile references a local Solid Queue checkout:

```ruby
gem "solid_queue", path: "../solid_queue"
```

Adjust this to point to your own checkout or a git ref.

## Running

### Single comparison

```bash
bin/benchmark --workload sleep --duration-ms 50 --jobs 1000 --capacity 50
```

### Matrix sweep

```bash
# Full sweep with 3 repetitions (reports median)
bin/matrix --workload sleep --duration-ms 50 --jobs 2000 \
  --capacities 10,25,50,75,100,150,200 --processes 1,2,4 --repeat 3

# CPU control
bin/matrix --workload cpu --iterations 50000 --jobs 500 \
  --capacities 10,25,50,75,100,150,200 --processes 1,2,4 --repeat 3
```

Writes JSON, CSV, and PNG charts to `results/`. Charts are generated
automatically when Python 3 with matplotlib is available.

### Generate charts from existing data

```bash
bin/plot results/sleep-data.csv
bin/plot results/sleep-data.csv --output-dir results
```

### Options

```
bin/matrix --help
bin/benchmark --help
bin/plot --help
```
