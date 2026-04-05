# Benchmark Results

Benchmark outputs live in the per-family directories below.

Solid Queue commit under test: `305bf4018352e099019f9f24502a18ee4794e64e`

| Family | What It Shows | Summary | Workloads |
|---|---|---|---|
| Async::Job | Throughput ceiling reference. Different backend (Redis), so read as a separate claim from the Solid Queue comparison. | [README](async-job/README.md) | [Async::HTTP](async-job/async-http-data.json), [CPU](async-job/cpu-data.json), [RubyLLM Stream](async-job/ruby-llm-stream-data.json), [Sleep](async-job/sleep-data.json) |
| Solid Queue | Same backend, different execution mode. Shows whether `async` delivers good I/O performance without thread-sized DB pools. | [README](solid-queue/README.md) | [Async::HTTP](solid-queue/async-http-data.json), [CPU](solid-queue/cpu-data.json), [RubyLLM Stream](solid-queue/ruby-llm-stream-data.json), [Sleep](solid-queue/sleep-data.json) |
| Solid Queue Stress | Failure-envelope tests. Shows where `thread` stops completing tests under pressure while `async` keeps going. | [README](solid-queue-stress/README.md) | [Async::HTTP](solid-queue-stress/async-http-data.json), [RubyLLM Stream](solid-queue-stress/ruby-llm-stream-data.json), [Sleep](solid-queue-stress/sleep-data.json) |

## Headline Workloads

- `sleep`: Sleep
- `cpu`: CPU
- `async_http`: Async::HTTP
- `ruby_llm_stream`: RubyLLM Stream

## Headline Plots

- [Headline Throughput Ranges](headline-throughput-ranges.png)
- [Headline Representative Test](headline-representative-cell.png)

## Stress Plots

- [Stress Test Status](solid-queue-stress/stress-cell-status.png)
- [Stress Throughput Envelope](solid-queue-stress/stress-throughput-envelope.png)
- [Stress RSS Envelope](solid-queue-stress/stress-rss-envelope.png)

Authoritative outputs live in the family directories above. Loose top-level files are scratch artifacts.
