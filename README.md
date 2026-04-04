# Solid Queue Bench

Benchmark harness for two related job-system questions:

1. **Within Solid Queue:** how much do I/O-heavy workloads benefit from the new
   `async` worker execution mode compared to `thread` mode?
2. **Across backends:** how does **Solid Queue** compare to **Async::Job +
   Redis** when both are driven through `ActiveJob`?

The benchmark focuses on throughput, memory, CPU, queue delay, service time,
and end-to-end latency.

## Benchmark Families

### 1. Solid Queue

This family compares:

- `thread`
- `async`

against the same Solid Queue backend and the same Rails app.

### 2. Async::Job

This family uses:

- `ActiveJob` adapter: `:async_job`
- queue backend: Redis
- worker execution: async/fiber-based

`Async::Job` does not expose a built-in capacity knob comparable to Solid
Queue, so this harness applies a queue-side concurrency limiter. That makes the
`capacity` matrix dimension mean “maximum concurrent jobs per worker process”
for both families instead of letting Redis-backed workers run unbounded.

## Workloads

### Headline workloads

These are the ones intended for charts and conclusions:

| Workload | Shape | Purpose |
|----------|-------|---------|
| `sleep` | `Kernel.sleep` | Pure cooperative wait upper bound |
| `cpu` | SHA256 loop | CPU-bound control |
| `async_http` | local `Async::HTTP` call | realistic fiber-friendly I/O |
| `ruby_llm_stream` | fake OpenAI SSE + real RubyLLM chat path + Turbo broadcast jobs | production-shaped streaming chat workload |

### Supplementary workloads

These are useful controls or topology probes, but they are not the main story:

| Workload | Shape | Use |
|----------|-------|-----|
| `http` | local `Net::HTTP` call | blocking HTTP control |
| `llm_batch` | long synthetic external wait | long I/O hold without network noise |
| `llm_stream` | synthetic parent job + child broadcast jobs | queue fan-out topology without RubyLLM/network layers |

## Measurement Notes

The harness now fixes the earlier measurement problems:

- timing starts **after workers are ready**
- benchmark rows are created and enqueued in bulk
- `jobs_per_second` counts **successful jobs only**
- latency percentiles are computed from **successful jobs only**
- repeated cells report a real representative run, not a synthetic hybrid row
- streaming workloads are **child-job aware**, so a run is not complete until
  downstream broadcast jobs finish too

Each result row includes:

- `jobs_per_second`: successful jobs / total wall time
- `finished_jobs_per_second`: all finished attempts / total wall time
- `drain_jobs_per_second`: successful jobs / post-enqueue drain window
- `execution_jobs_per_second`: successful jobs / first successful start to last finish
- RSS and CPU samples across worker processes
- queue delay, service time, and total latency percentiles

## Headline Matrix Defaults

The default headline sweep is intentionally narrower than the old one:

- capacities: `5,10,25,50,100`
- Solid Queue processes: `1,2,6`
- Async::Job processes: `1,2,6`
- repeats: `3`

Stress capacities `150,200` are available in the full suites.

Environment overrides:

```bash
CAPACITIES=5,10,25,50,100
STRESS_CAPACITIES=150,200
SOLID_QUEUE_PROCESSES=1,2,6
ASYNC_JOB_PROCESSES=1,2,6
REPEAT=3
```

## Setup

Requirements:

- Ruby 4.0+
- PostgreSQL
- Docker-backed Redis for the Async::Job family, or a local Redis on `127.0.0.1:6379`

When `REDIS_HOST` is local and Docker is available, the Async::Job benchmark
path will start a local `redis:7-alpine` container automatically if Redis is
not already reachable.

Database credentials:

```bash
export DB_USER=your_user
export DB_PASSWORD=your_password
# optional: DB_HOST, DB_PORT
```

Redis defaults:

```bash
export REDIS_HOST=127.0.0.1
export REDIS_PORT=6379
export REDIS_DB=15
export REDIS_PREFIX=solid_queue_bench:development
```

Then:

```bash
bin/setup
```

`bin/setup` now:

- installs gems
- prepares the database
- ensures Solid Queue schema exists
- loads the RubyLLM model catalog used by `ruby_llm_stream`

The Gemfile expects a local Solid Queue checkout:

```ruby
gem "solid_queue", path: "../solid_queue"
```

## Running

### Single benchmark

Solid Queue:

```bash
bin/benchmark --backend solid_queue --modes thread,async \
  --workload async_http --duration-ms 50 --jobs 1000 --capacity 50 --processes 1
```

Async::Job:

```bash
bin/benchmark --backend async_job --modes async \
  --workload async_http --duration-ms 50 --jobs 1000 --capacity 50 --processes 1
```

RubyLLM streaming:

```bash
bin/benchmark --backend solid_queue --modes thread,async \
  --workload ruby_llm_stream --jobs 20 --capacity 25 --processes 1 \
  --token-count 40 --token-delay-ms 20 --llm-model gpt-4.1-mini
```

### Matrix

Solid Queue:

```bash
bin/matrix --backend solid_queue --workload async_http --jobs 1000 \
  --capacities 5,10,25,50,100 --processes 1,2,6 --modes thread,async --repeat 3
```

Async::Job:

```bash
bin/matrix --backend async_job --workload async_http --jobs 1000 \
  --capacities 5,10,25,50,100 --processes 1,2,6 --modes async --repeat 3
```

### Sweep tasks

Headline Solid Queue suite:

```bash
bundle exec rake sweep:solid_queue_headline
```

Headline Async::Job suite:

```bash
bundle exec rake sweep:async_job_headline
```

Both headline families:

```bash
bundle exec rake sweep:families
```

Full suites including supplementary workloads and stress capacities:

```bash
bundle exec rake sweep:solid_queue_full
bundle exec rake sweep:async_job_full
bundle exec rake sweep:full
```

Single-workload sweeps:

```bash
bundle exec rake sweep:sleep
bundle exec rake sweep:ruby_llm_stream
bundle exec rake sweep:async_job_sleep
bundle exec rake sweep:async_job_ruby_llm_stream
```

### Charts

Charts are generated automatically when Python 3 with matplotlib is available.
Benchmark summary indexes are generated automatically by the sweep tasks and can
also be refreshed manually with:

```bash
bin/report
```

This regenerates:

- `results/README.md`
- `results/solid-queue/README.md`
- `results/async-job/README.md`

Manual plotting:

```bash
bin/plot results/solid-queue/sleep-data.csv
bin/plot results/async-job/sleep-data.csv
```

## Output Layout

Per-family results are written to:

- `results/solid-queue/`
- `results/async-job/`

Matrix JSON/CSV artifacts are written to:

- `tmp/benchmarks/solid-queue/`
- `tmp/benchmarks/async-job/`

## RubyLLM Streaming Benchmark

`ruby_llm_stream` is the main production-shaped streaming benchmark.

It uses:

- the generated RubyLLM chat stack
- a local fake OpenAI-compatible `/v1/chat/completions` SSE server
- the real `chat.ask` streaming path
- per-token Turbo broadcast jobs

That keeps the benchmark local and repeatable while still exercising the Rails
job topology you would actually use in a streaming chat UI.

## Caveats

- Checked-in `results/` files may be smoke outputs or historical artifacts. If
  you want publishable numbers, rerun the suites on a quiet machine.
- `llm_batch` and `llm_stream` are synthetic. They are useful, but they are not
  a substitute for `ruby_llm_stream`.
- The benchmark uses aggressive queue polling for the Solid Queue family, so it
  is best understood as a comparison of execution/back-end behavior under a
  low-latency benchmark configuration, not a benchmark of untouched default
  production settings.
