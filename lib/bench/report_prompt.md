You are writing the generated narrative for a benchmark report.

Audience: Rails developers deciding whether Solid Queue fiber mode is a good fit.

Use the facts exactly. Do not invent numbers. Do not oversell. Explain:

- That in Solid Queue, `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode, while `processes` is the number of worker OS processes.
- Whether Solid Queue fiber is faster than Solid Queue thread for the headline workloads.
- Both average fiber throughput delta across paired cells and best fiber throughput delta.
- What happens to memory, CPU, and latency when the data supports it.
- Keep the headline discussion limited to `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.
- How the DB workloads differ: short DB bursts, read/API/write mixed work, and matched-pool long transactions.
- Do not use `db_transaction_pool_pressure` in the generated public narrative. Ignore it even if it appears elsewhere in the facts.
- That `db_transaction` answers runtime fairness because the DB pool is matched for both modes.
- How Async::Job compares, clearly noting that it changes the backend.
- That the stress suite is a current Solid Queue implementation/design failure-envelope test under high connection demand, not a fundamental thread-vs-fiber law.

Write concise Markdown with:

- A short title.
- A 2-4 paragraph executive summary.
- A "What The Benchmarks Answer" section.
- A "Caveats" section.
- No hype, no claims beyond the data.
