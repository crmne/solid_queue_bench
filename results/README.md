# Benchmark Results

Benchmark outputs live in the per-family directories below. The generated narrative is in [narrative.md](narrative.md).

RubyLLM 2.0 versus main, with connection reuse: [comparison](ruby-llm/README.md).


| Family | What It Shows | Summary |
|---|---|---|
| Solid Queue | Same backend, different executor. Primary sweep tasks use matched DB pools for the direct Solid Queue thread-vs-fiber comparison. | [README](solid-queue/README.md) |
| Async::Job | Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison. | [README](async-job/README.md) |
| Solid Queue Stress | Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells. | [README](solid-queue-stress/README.md) |

## Headline Charts

- [Headline Solid Queue Fiber Vs Thread](charts/headline-solid-queue-fiber-vs-thread.svg)
- [Headline Solid Queue Fiber Vs Thread Rss](charts/headline-solid-queue-fiber-vs-thread-rss.svg)
- [Headline Solid Queue Fiber Vs Thread Cpu](charts/headline-solid-queue-fiber-vs-thread-cpu.svg)
- [Headline Solid Queue Fiber Vs Thread Latency](charts/headline-solid-queue-fiber-vs-thread-latency.svg)
- [Headline Async Job Vs Solid Queue Fiber](charts/headline-async-job-vs-solid-queue-fiber.svg)

## Stress Charts

- [Stress Cell Status](charts/stress-cell-status.svg)
