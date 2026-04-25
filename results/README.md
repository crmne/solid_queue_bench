# Benchmark Results

Benchmark outputs live in the per-family directories below. The generated narrative is in [narrative.md](narrative.md).

Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

| Family | What It Shows | Summary |
|---|---|---|
| Solid Queue | Same backend, different executor. This is the direct Solid Queue thread-vs-fiber comparison. | [README](solid-queue/README.md) |
| Async::Job | Different backend and executor. Use it as a throughput ceiling reference, not a same-backend comparison. | [README](async-job/README.md) |
| Solid Queue Stress | Failure-envelope runs that show where high-concurrency thread workers stop completing planned cells. | [README](solid-queue-stress/README.md) |

## Headline Charts

- [Headline Solid Queue Fiber Vs Thread](charts/headline-solid-queue-fiber-vs-thread.svg)
- [Headline Async Job Vs Solid Queue Fiber](charts/headline-async-job-vs-solid-queue-fiber.svg)

## Stress Charts

- [Stress Cell Status](charts/stress-cell-status.svg)
- [Stress Throughput](charts/stress-throughput.svg)
- [Stress Rss](charts/stress-rss.svg)
