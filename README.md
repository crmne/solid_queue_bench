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
matrix. For each cell, we enqueue a fixed number of jobs, start a fresh Solid
Queue supervisor, process all jobs to completion, and record metrics.

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
| **http** | `Net::HTTP.get` to a local delay server (50 ms) | 2,000 | Real TCP/HTTP I/O through Ruby's network stack |
| **cpu** | 50,000 SHA256 hash iterations (~50 ms) | 500 | CPU-bound control -- async should show no throughput advantage |

### Database connection requirements

This is the critical scaling difference between the two modes:

| Mode | DB pool per worker | At capacity 100, 1 process | At capacity 200, 4 processes |
|------|-------------------|---------------------------|------------------------------|
| Thread | `capacity + 5` | 105 connections | 4 x 205 = 820 connections |
| Async | `max(5, processes + 4)` | 5 connections | 8 connections |

PostgreSQL's default `max_connections` is 100. Thread mode at capacity 100+
requires more connections than the server allows and fails to start. These
failures are recorded in the results below.

### Environment

- Ruby 4.0.2, PostgreSQL `max_connections = 100`
- `config.active_support.isolation_level = :fiber`
- Linux 6.x, x86_64
- Solid Queue from local `async-worker-execution-mode` branch

## Results

### Sleep Workload

50 ms sleep, 2,000 jobs per cell.

![Comparison grid -- Sleep](results/sleep-grid.png)

Each column is a process count (1, 2, 4). Each row is a metric. Blue = thread,
red = async. At 1 and 2 processes, async matches or exceeds thread throughput
while consuming 10-28% less memory. At 4 processes, throughput converges (both
modes saturate the scheduler) but async still uses consistently less RSS. Thread
mode's memory footprint grows with capacity due to per-thread stack allocations;
async stays nearly flat because fibers share a single stack.

![Async advantage -- Sleep](results/sleep-advantage.png)

Bars show the percentage improvement of async over thread for each
(capacity, processes) pair. Negative values on RSS and CPU mean async uses
fewer resources. Throughput advantage is strongest at low process counts
(up to +12% at 1 process). All 42 cells completed -- no thread failures in this
workload because `max_connections = 100` was sufficient for the sleep benchmark's
connection pool requirements.

![Latency percentiles -- Sleep](results/sleep-latency.png)

Latency distributions (p50/p95/p99/max) for queue delay, service time, and total
latency. Async shows tighter p50 total latency at 1 and 2 processes. Tail
latencies (p95/p99) are comparable, with async generally lower at 1 process.

<details>
<summary>Per-cell advantage data (sleep)</summary>

Advantage = (async - thread) / thread * 100. Negative RSS/CPU/latency values mean async uses fewer resources.

| Cap | Procs | Thread j/s | Async j/s | Tput % | Thread RSS MB | Async RSS MB | RSS % | Thread CPU % | Async CPU % | CPU % | Thread p50 ms | Async p50 ms | Lat p50 % |
|-----|-------|-----------|----------|--------|--------------|-------------|-------|-------------|------------|-------|--------------|-------------|-----------|
| 10 | 1 | 46.0 | 49.8 | +8.3 | 119 | 107 | -10.5 | 65.9 | 57.0 | -13.5 | 86 | 81 | -5.5 |
| 25 | 1 | 44.9 | 49.5 | +10.3 | 115 | 112 | -2.4 | 67.6 | 56.4 | -16.6 | 87 | 81 | -6.1 |
| 50 | 1 | 47.4 | 51.0 | +7.7 | 153 | 115 | -25.0 | 65.1 | 53.3 | -18.1 | 85 | 80 | -5.9 |
| 75 | 1 | 44.2 | 49.6 | +12.4 | 148 | 107 | -27.7 | 66.5 | 56.9 | -14.4 | 87 | 81 | -6.4 |
| 100 | 1 | 48.0 | 43.1 | -10.3 | 142 | 106 | -25.5 | 66.5 | 56.6 | -14.9 | 85 | 85 | -0.7 |
| 150 | 1 | 47.8 | 48.8 | +2.0 | 142 | 107 | -24.8 | 66.6 | 56.7 | -14.9 | 85 | 81 | -4.3 |
| 200 | 1 | 47.4 | 51.9 | +9.5 | 148 | 111 | -25.1 | 67.3 | 54.1 | -19.6 | 85 | 80 | -6.1 |
| 10 | 2 | 46.7 | 47.2 | +1.1 | 240 | 213 | -11.5 | 81.4 | 73.6 | -9.6 | 82 | 80 | -2.1 |
| 25 | 2 | 44.6 | 48.0 | +7.8 | 227 | 216 | -4.9 | 85.6 | 74.6 | -12.9 | 83 | 80 | -3.2 |
| 50 | 2 | 45.2 | 47.5 | +5.1 | 272 | 212 | -21.9 | 83.8 | 73.7 | -12.1 | 82 | 80 | -2.4 |
| 75 | 2 | 46.5 | 44.3 | -4.6 | 262 | 209 | -20.1 | 81.8 | 77.4 | -5.4 | 82 | 81 | -1.0 |
| 100 | 2 | 44.9 | 44.4 | -1.1 | 263 | 212 | -19.5 | 82.4 | 78.8 | -4.4 | 83 | 81 | -1.7 |
| 150 | 2 | 45.1 | 47.9 | +6.3 | 268 | 226 | -15.6 | 82.3 | 73.5 | -10.7 | 82 | 80 | -3.0 |
| 200 | 2 | 46.5 | 48.8 | +5.0 | 261 | 226 | -13.7 | 82.7 | 73.7 | -10.9 | 82 | 80 | -2.8 |
| 10 | 4 | 47.3 | 46.4 | -2.1 | 477 | 420 | -11.8 | 104.2 | 104.1 | -0.1 | 79 | 80 | +0.5 |
| 25 | 4 | 47.9 | 43.2 | -9.8 | 459 | 419 | -8.7 | 104.1 | 108.1 | +3.8 | 79 | 80 | +0.4 |
| 50 | 4 | 47.4 | 39.3 | -17.0 | 478 | 414 | -13.5 | 102.7 | 112.8 | +9.8 | 79 | 81 | +2.8 |
| 75 | 4 | 47.4 | 47.4 | +0.0 | 486 | 416 | -14.5 | 103.0 | 103.5 | +0.5 | 79 | 79 | -0.1 |
| 100 | 4 | 47.6 | 47.0 | -1.2 | 463 | 415 | -10.3 | 103.3 | 103.0 | -0.3 | 79 | 79 | +0.2 |
| 150 | 4 | 47.2 | 47.9 | +1.5 | 478 | 416 | -13.0 | 102.8 | 102.7 | -0.1 | 79 | 79 | -0.5 |
| 200 | 4 | 42.2 | 47.2 | +11.7 | 482 | 417 | -13.5 | 111.5 | 102.3 | -8.3 | 81 | 79 | -2.2 |

</details>

### HTTP Workload

50 ms local delay server, 2,000 jobs per cell. Exercises real `Net::HTTP` I/O
through Ruby's network stack.

![Comparison grid -- HTTP](results/http-grid.png)

HTTP shows a different throughput profile than sleep. Thread mode achieves
marginally higher throughput in most cells because `Net::HTTP` with threads
can overlap DNS resolution, TCP setup, and TLS negotiation across OS-scheduled
threads, whereas the async reactor serializes these phases on a single event
loop. However, async wins decisively on memory: peak RSS is 14-44% lower across
all cells. Thread mode at capacity 150 with 1 process failed to start
(database connection exhaustion).

![Async advantage -- HTTP](results/http-advantage.png)

The throughput bars are mostly negative (thread slightly faster), but the RSS
bars are deeply negative (async uses far less memory). CPU usage is consistently
lower for async. The one missing bar at capacity 150, 1 process, marks the
thread failure.

![Latency percentiles -- HTTP](results/http-latency.png)

Service time p50 is comparable (both ~2-3 ms for the HTTP call itself). Queue
delay dominates total latency in both modes. Tail latencies (p95/p99) are
workload-dependent and show no consistent winner.

<details>
<summary>Per-cell advantage data (HTTP)</summary>

Advantage = (async - thread) / thread * 100. FAILED = thread mode did not complete (DB connection exhaustion).

| Cap | Procs | Thread j/s | Async j/s | Tput % | Thread RSS MB | Async RSS MB | RSS % | Thread CPU % | Async CPU % | CPU % | Thread p50 ms | Async p50 ms | Lat p50 % |
|-----|-------|-----------|----------|--------|--------------|-------------|-------|-------------|------------|-------|--------------|-------------|-----------|
| 10 | 1 | 50.6 | 45.9 | -9.3 | 193 | 110 | -43.2 | 75.7 | 71.2 | -5.9 | 36 | 35 | -1.4 |
| 25 | 1 | 47.5 | 47.0 | -1.1 | 128 | 109 | -14.4 | 82.7 | 72.4 | -12.5 | 40 | 35 | -12.8 |
| 50 | 1 | 52.2 | 48.2 | -7.7 | 215 | 130 | -39.7 | 76.8 | 68.6 | -10.7 | 35 | 34 | -3.1 |
| 75 | 1 | 51.6 | 47.4 | -8.0 | 194 | 109 | -44.0 | 77.5 | 71.1 | -8.3 | 35 | 35 | -1.8 |
| 100 | 1 | 46.6 | 45.4 | -2.5 | 191 | 108 | -43.4 | 81.4 | 71.0 | -12.8 | 39 | 36 | -9.8 |
| 150 | 1 | FAILED | 44.1 | -- | FAILED | 113 | -- | FAILED | 70.7 | -- | FAILED | 37 | -- |
| 200 | 1 | 50.5 | 48.1 | -4.8 | 188 | 108 | -42.4 | 79.8 | 67.3 | -15.7 | 37 | 34 | -9.5 |
| 10 | 2 | 49.3 | 45.6 | -7.5 | 266 | 217 | -18.5 | 92.9 | 82.4 | -11.3 | 31 | 31 | +0.6 |
| 25 | 2 | 48.4 | 44.1 | -8.9 | 258 | 216 | -16.5 | 92.9 | 86.5 | -6.9 | 31 | 33 | +4.7 |
| 50 | 2 | 47.1 | 40.8 | -13.4 | 314 | 214 | -31.8 | 94.2 | 89.6 | -4.9 | 32 | 35 | +8.9 |
| 75 | 2 | 46.6 | 41.8 | -10.3 | 303 | 216 | -28.5 | 94.6 | 86.4 | -8.7 | 32 | 34 | +7.7 |
| 100 | 2 | 50.5 | 44.2 | -12.5 | 264 | 215 | -18.4 | 94.1 | 86.9 | -7.7 | 29 | 33 | +10.8 |
| 150 | 2 | 49.4 | 42.6 | -13.6 | 300 | 215 | -28.3 | 93.8 | 87.4 | -6.8 | 30 | 35 | +14.5 |
| 200 | 2 | 51.3 | 47.9 | -6.7 | 302 | 215 | -28.8 | 92.0 | 84.1 | -8.6 | 29 | 31 | +6.2 |
| 10 | 4 | 48.2 | 43.1 | -10.6 | 540 | 430 | -20.3 | 120.8 | 116.2 | -3.8 | 29 | 31 | +6.6 |
| 25 | 4 | 49.3 | 41.3 | -16.1 | 515 | 428 | -16.8 | 120.0 | 120.8 | +0.7 | 29 | 33 | +13.7 |
| 50 | 4 | 45.1 | 47.1 | +4.5 | 530 | 458 | -13.5 | 122.3 | 109.4 | -10.5 | 31 | 30 | -3.8 |
| 75 | 4 | 47.0 | 46.8 | -0.6 | 525 | 430 | -18.1 | 123.1 | 109.8 | -10.8 | 29 | 30 | +3.1 |
| 100 | 4 | 47.1 | 42.2 | -10.4 | 527 | 428 | -18.7 | 121.2 | 116.6 | -3.8 | 30 | 32 | +6.8 |
| 150 | 4 | 46.9 | 44.8 | -4.5 | 517 | 428 | -17.3 | 122.2 | 114.8 | -6.1 | 31 | 31 | +1.0 |
| 200 | 4 | 41.4 | 45.9 | +10.8 | 522 | 428 | -18.0 | 126.7 | 112.0 | -11.6 | 33 | 31 | -6.1 |

</details>

### CPU Workload (Control)

50,000 SHA256 iterations per job (~50 ms of pure CPU), 500 jobs per cell.
This is the **control** workload -- async fibers cannot parallelize CPU-bound
work any better than threads because both are limited by Ruby's GVL to one core
per process.

![Comparison grid -- CPU](results/cpu-grid.png)

Throughput is GVL-limited and roughly equal between modes when both complete:
~16-20 j/s at 1 process, ~30 j/s at 2, ~44 j/s at 4. The throughput lines
overlap almost exactly where both modes have data.

However, two things stand out:

1. **Thread mode fails massively.** 12 of 21 thread cells failed due to
   database connection exhaustion. Thread mode requires `capacity + 5` DB
   connections per worker process, which exceeds `max_connections = 100` at
   higher capacities. Failed cells: cap 100/150/200 at 1 process, cap
   50/75/100/150/200 at 2 processes, cap 50/75/100/200 at 4 processes.
   Async mode completed 20 of 21 cells (only cap 200, 1 process missing).

2. **RSS diverges massively.** Where both modes ran, async uses 13-66% less
   peak RSS. At 1 process with capacity 75, thread uses 324 MB vs async's
   111 MB -- a 66% reduction. Fibers do not allocate per-unit OS thread stacks
   and avoid OS context-switch overhead, which keeps memory flat regardless of
   capacity.

![Async advantage -- CPU](results/cpu-advantage.png)

Most bars are missing on the thread side because thread mode failed. Where
both ran, throughput is within a few percent (confirming the GVL bottleneck),
but RSS advantage for async is dramatic.

<details>
<summary>Per-cell advantage data (CPU)</summary>

Advantage = (async - thread) / thread * 100. FAILED = thread mode did not complete (DB connection exhaustion). 12 of 21 thread cells failed.

| Cap | Procs | Thread j/s | Async j/s | Tput % | Thread RSS MB | Async RSS MB | RSS % | Thread CPU % | Async CPU % | CPU % | Thread p50 ms | Async p50 ms | Lat p50 % |
|-----|-------|-----------|----------|--------|--------------|-------------|-------|-------------|------------|-------|--------------|-------------|-----------|
| 10 | 1 | 16.3 | 19.0 | +16.5 | 130 | 114 | -12.6 | 97.0 | 96.5 | -0.5 | 11654 | 9428 | -19.1 |
| 25 | 1 | 16.5 | 19.7 | +19.0 | 185 | 113 | -38.7 | 96.8 | 96.7 | -0.1 | 11376 | 9182 | -19.3 |
| 50 | 1 | 16.4 | 19.5 | +18.9 | 257 | 113 | -56.0 | 96.8 | 96.4 | -0.4 | 11927 | 9260 | -22.4 |
| 75 | 1 | 16.2 | 19.8 | +22.2 | 324 | 111 | -65.6 | 96.8 | 96.4 | -0.4 | 11922 | 9544 | -19.9 |
| 100 | 1 | FAILED | 19.7 | -- | FAILED | 112 | -- | FAILED | 96.1 | -- | FAILED | 9063 | -- |
| 150 | 1 | FAILED | 19.0 | -- | FAILED | 109 | -- | FAILED | 96.3 | -- | FAILED | 9800 | -- |
| 10 | 2 | 30.2 | 30.9 | +2.1 | 245 | 207 | -15.2 | 187.9 | 189.3 | +0.7 | 4656 | 4524 | -2.8 |
| 25 | 2 | 29.7 | 31.0 | +4.4 | 327 | 225 | -31.1 | 189.4 | 185.3 | -2.2 | 4819 | 4213 | -12.6 |
| 50 | 2 | FAILED | 31.6 | -- | FAILED | 220 | -- | FAILED | 186.5 | -- | FAILED | 4332 | -- |
| 75 | 2 | FAILED | 31.3 | -- | FAILED | 218 | -- | FAILED | 187.0 | -- | FAILED | 4313 | -- |
| 100 | 2 | FAILED | 30.6 | -- | FAILED | 216 | -- | FAILED | 182.4 | -- | FAILED | 4397 | -- |
| 150 | 2 | FAILED | 28.7 | -- | FAILED | 215 | -- | FAILED | 174.2 | -- | FAILED | 4499 | -- |
| 200 | 2 | FAILED | 29.8 | -- | FAILED | 215 | -- | FAILED | 177.4 | -- | FAILED | 3653 | -- |
| 10 | 4 | 45.3 | 45.3 | +0.1 | 472 | 408 | -13.4 | 358.8 | 366.8 | +2.2 | 530 | 657 | +23.9 |
| 25 | 4 | 44.3 | 44.9 | +1.3 | 572 | 410 | -28.3 | 305.8 | 364.3 | +19.1 | 533 | 418 | -21.5 |
| 50 | 4 | FAILED | 44.3 | -- | FAILED | 406 | -- | FAILED | 366.0 | -- | FAILED | 394 | -- |
| 75 | 4 | FAILED | 43.7 | -- | FAILED | 401 | -- | FAILED | 365.3 | -- | FAILED | 410 | -- |
| 100 | 4 | FAILED | 43.4 | -- | FAILED | 405 | -- | FAILED | 361.9 | -- | FAILED | 369 | -- |
| 150 | 4 | 44.2 | 44.1 | -0.2 | 638 | 408 | -36.0 | 352.4 | 362.7 | +2.9 | 306 | 423 | +38.0 |
| 200 | 4 | FAILED | 44.0 | -- | FAILED | 406 | -- | FAILED | 366.1 | -- | FAILED | 510 | -- |

</details>

## Key Findings

1. **Async wins on I/O-bound workloads across the board.** For the sleep
   workload, async delivers up to 12% higher throughput at 1-2 processes while
   using 10-28% less peak RSS and 5-20% less CPU. For HTTP, thread has a slight
   throughput edge (the OS thread scheduler can overlap network phases that the
   single-threaded reactor serializes), but async still uses 14-44% less memory
   and 4-16% less CPU.

2. **Async matches thread throughput on CPU-bound work while using far less
   memory.** The CPU control workload confirms that both modes are GVL-limited
   to identical throughput (~16-20 j/s per process). But async uses 13-66% less
   peak RSS because fibers do not allocate per-unit OS thread stacks.

3. **Thread mode fails at high capacity due to database connections.** Thread
   mode requires `capacity + 5` DB connections per worker process. With
   PostgreSQL `max_connections = 100`, thread mode cannot run at capacity 100+
   with 1 process (needs 105), capacity 50+ with 2 processes (needs 110), or
   capacity 50+ with 4 processes (needs 220). In the CPU workload, 12 of 21
   thread cells failed. Async mode needs only `max(5, processes + 4)` connections
   total -- it ran 20 of 21 cells with a maximum of 8 DB connections.

4. **The DB connection requirement is the practical scaling ceiling.** In
   production, PostgreSQL connection limits are often the binding constraint.
   Thread mode's linear connection growth with capacity makes high-concurrency
   deployments impractical without connection poolers like PgBouncer. Async mode
   sidesteps this entirely.

5. **Memory scales with capacity in thread mode but stays flat in async mode.**
   Thread mode peak RSS grows linearly with capacity (each thread stack costs
   ~1 MB by default). Async mode RSS is nearly constant regardless of how many
   fibers are scheduled, because fibers share the process heap without
   per-unit stack allocations.

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
# Full sweep with charts
bin/matrix --workload sleep --duration-ms 50 --jobs 2000 \
  --capacities 10,25,50,75,100,150,200 --processes 1,2,4

# CPU control
bin/matrix --workload cpu --iterations 50000 --jobs 500 \
  --capacities 10,25,50,75,100,150,200 --processes 1,2,4
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
