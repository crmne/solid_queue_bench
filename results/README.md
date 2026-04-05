# Benchmark Results

Current benchmark outputs live in the per-family directories below.

| Family | What It Shows | Summary | Workloads |
|---|---|---|---|
| Async::Job | Separate backend reference point. This family answers the maximum-throughput question, not the same-backend execution-mode question. | [README](async-job/README.md) | [Async::HTTP](async-job/async-http-data.json), [CPU](async-job/cpu-data.json), [RubyLLM Stream](async-job/ruby-llm-stream-data.json), [Sleep](async-job/sleep-data.json) |
| Solid Queue | Same backend, different execution mode. The practical question here is whether `async` preserves good performance while avoiding thread-sized DB pools and connection pressure. | [README](solid-queue/README.md) | [Async::HTTP](solid-queue/async-http-data.json), [CPU](solid-queue/cpu-data.json), [RubyLLM Stream](solid-queue/ruby-llm-stream-data.json), [Sleep](solid-queue/sleep-data.json) |
| Solid Queue Stress | Failure-envelope tests for Solid Queue. This family is about where `thread` stops completing tests under higher pressure, while `async` keeps going. | [README](solid-queue-stress/README.md) | [Async::HTTP](solid-queue-stress/async-http-data.json), [RubyLLM Stream](solid-queue-stress/ruby-llm-stream-data.json), [Sleep](solid-queue-stress/sleep-data.json) |

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

Published outputs live in these family directories. If loose top-level files ever appear here, treat them as non-authoritative scratch artifacts.
