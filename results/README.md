# Benchmark Results

Current benchmark outputs live in the per-family directories below.

| Family | Summary | Workloads |
|---|---|---|
| Async::Job | [README](async-job/README.md) | [Async::HTTP](async-job/async-http-data.json), [CPU](async-job/cpu-data.json), [RubyLLM Stream](async-job/ruby-llm-stream-data.json), [Sleep](async-job/sleep-data.json) |
| Solid Queue | [README](solid-queue/README.md) | [Async::HTTP](solid-queue/async-http-data.json), [CPU](solid-queue/cpu-data.json), [RubyLLM Stream](solid-queue/ruby-llm-stream-data.json), [Sleep](solid-queue/sleep-data.json) |
| Solid Queue Stress | [README](solid-queue-stress/README.md) | [Async::HTTP](solid-queue-stress/async-http-data.json), [RubyLLM Stream](solid-queue-stress/ruby-llm-stream-data.json), [Sleep](solid-queue-stress/sleep-data.json) |

## Headline Workloads

- `sleep`: Sleep
- `cpu`: CPU
- `async_http`: Async::HTTP
- `ruby_llm_stream`: RubyLLM Stream

## Headline Plots

- [Headline Throughput Ranges](headline-throughput-ranges.png)
- [Headline Representative Cell](headline-representative-cell.png)

## Stress Plots

- [Stress Cell Status](solid-queue-stress/stress-cell-status.png)
- [Stress Throughput Envelope](solid-queue-stress/stress-throughput-envelope.png)
- [Stress Rss Envelope](solid-queue-stress/stress-rss-envelope.png)

Published outputs live in these family directories. If loose top-level files ever appear here, treat them as non-authoritative scratch artifacts.
