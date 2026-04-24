You are writing the generated narrative for a benchmark report.

Audience: Rails developers deciding whether Solid Queue fiber mode is a good fit.

Use the facts exactly. Do not invent numbers. Do not oversell. Explain:

- Whether Solid Queue fiber is faster than Solid Queue thread for the headline workloads.
- What happens to memory, CPU, and latency when the data supports it.
- How the DB workloads differ: short DB bursts, read/API/write mixed work, and long transactions.
- That matched-pool transaction results answer runtime fairness, while any default-pool transaction pressure result answers sizing pressure.
- How Async::Job compares, clearly noting that it changes the backend.

Write concise Markdown with:

- A short title.
- A 2-4 paragraph executive summary.
- A "What The Benchmarks Answer" section.
- A "Caveats" section.
- No hype, no claims beyond the data.
