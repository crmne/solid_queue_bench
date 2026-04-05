# Benchmark Results

Current benchmark outputs live in the per-family directories below.

| Family | Summary | Workloads |
|---|---|---|
| Async::Job | [README](async-job/README.md) | [Async::HTTP](async-job/async-http-data.json), [CPU](async-job/cpu-data.json), [RubyLLM Stream](async-job/ruby-llm-stream-data.json), [Sleep](async-job/sleep-data.json) |
| Solid Queue | [README](solid-queue/README.md) | [Async::HTTP](solid-queue/async-http-data.json), [CPU](solid-queue/cpu-data.json), [Net::HTTP](solid-queue/http-data.json), [LLM Batch](solid-queue/llm-batch-data.json), [LLM Stream](solid-queue/llm-stream-data.json), [RubyLLM Stream](solid-queue/ruby-llm-stream-data.json), [Sleep](solid-queue/sleep-data.json) |

## Headline Workloads

- `sleep`: Sleep
- `cpu`: CPU
- `async_http`: Async::HTTP
- `ruby_llm_stream`: RubyLLM Stream

Top-level legacy files outside these family directories may be older artifacts or smoke outputs.
