You are writing the root README for a Rails benchmark repository.

Audience: Rails developers deciding whether Solid Queue fiber execution mode is a good fit.

Write a polished, human-readable Markdown README from the facts provided. Return only Markdown, with no code fences around the whole document.

Style:

- Direct, clear, and pragmatic.
- Same spirit as a strong Rails README: research question first, then methodology, then results, then how to run it.
- No hype and no claims beyond the supplied facts.
- Use exact numbers from the facts. Round percentages and numeric metrics to one decimal or two decimals where that reads better.
- Use the exact setup and running facts as supplied. Do not assume a local checkout, a path-based Gemfile entry, or any command that is not present in the facts.
- Define the benchmark terms clearly: in Solid Queue, `concurrency = N` means `threads: N` in thread mode or `fibers: N` in fiber mode; `processes` is the number of worker OS processes.
- Report both average fiber throughput delta and best fiber throughput delta when both are available.
- The `## Headline Results` section is only for the headline workloads: `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.
- Keep the DB transaction framing precise: `db_transaction` is the fair executor/runtime comparison because the DB pool is matched for both modes.
- Do not use `db_transaction_pool_pressure` in the public README headline or DB sections. Ignore it in the public README even if it appears elsewhere in the facts.
- Be explicit that Async::Job changes the backend, so it is a throughput-ceiling reference, not the same comparison as Solid Queue fiber vs thread.
- Treat the stress suite as a current Solid Queue implementation/design failure-envelope test under high connection demand, not as a fundamental thread-vs-fiber law.
- When relevant, note that the capped suites intentionally omit cells above the max total concurrency cap, so higher concurrencies may show only `1 proc` results.
- If `environment.ruby_version`, `environment.isolation_level`, or `environment.representative_run` are supplied, use them once where they help reproducibility, preferably in the introduction or methodology.
- If `db_pool_policies` are supplied, explain them plainly. Be explicit when the benchmark sets `DB_POOL` itself instead of relying on passive Rails defaults.
- Each result section should be understandable from the previous context alone. Prefer a short `### Method` paragraph before charts/tables and a short `### Interpretation` paragraph after them.
- For the stress section, explain what the status chart means and why completion matters more than throughput there.
- If multiple headline chart facts are supplied, use them. When the Solid Queue fiber-vs-thread charts include RSS, CPU, or latency deltas, make clear that positive percentages mean movement in fiber's favor.

Required structure:

1. `# Solid Queue Bench`
2. A short introduction explaining the benchmark and latest checked-in result date.
3. `## Research Questions`
4. `## Methodology`
5. `## Headline Results`, with the headline chart links or image links from the facts.
6. A headline Solid Queue results table covering only the headline workloads and covering throughput, memory, latency, average fiber throughput delta, and best fiber throughput delta.
7. `## DB Workloads`, covering `db_queries`, `db_mixed`, and `db_transaction`, with the DB-specific interpretation and the DB chart links if available.
8. `## Stress Suite`, explaining the completion/failure-envelope test and showing only the stress status chart when available.
9. `## Async::Job Comparison`
10. `## Workloads`
11. `## Setup`
12. `## Running`
13. `## Caveats`

In `## Running`, include the supplied `bin/report` command and the supplied note about single-workload sweeps when those facts are present.

Include these links exactly where useful:

- `results/README.md`
- `results/solid-queue/README.md`
- `results/async-job/README.md`
- `results/solid-queue-stress/README.md`

For charts, prefer Markdown image embeds when a chart fact has `embeddable: true`, using the provided `path` exactly. Otherwise use a normal Markdown link.

Use the supplied `setup` and `running` facts for setup and command sections. Do not invent prerequisites or commands.

Mention that `bin/report` uses RubyLLM for the public README and narrative when `OPENAI_API_KEY` is set.
