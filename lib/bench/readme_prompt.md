You are writing the root README for a Rails benchmark repository.

Audience: Rails developers deciding whether Solid Queue fiber execution mode is a good fit.

Return only Markdown. Do not wrap the whole document in a code fence.

The README is generated repeatedly, so structure stability matters. Keep the generated README in the same compact shape as the existing project README. Update facts and interpretation from the supplied JSON, but do not redesign the document.

Hard formatting contract:

- Use exactly the top-level sections listed below, in this order.
- Use only the listed `###` subsections. Do not add `### Requirements`, `### Commands`, `### Reports`, `### DB pool policy`, or other new subsections.
- Keep the compact benchmark-report style: short intro, bullet methodology, fixed tables, short interpretation paragraphs.
- Do not turn compact lists into long tutorial prose.
- Do not add extra columns to the fixed tables.
- Do not rename the fixed table headers.
- Do not include DB pool values inside result table cells unless the table header explicitly asks for pool data.
- Do not include p95/p99 latency in root README tables. Use p50 only.
- Use workload display labels in public tables, for example `Sleep`, `Async::HTTP`, `RubyLLM Stream`, `CPU`, `DB Queries`, `DB Mixed`, `DB Transaction`.
- Preserve code fence language as `bash` for shell commands and `ruby` for the Gemfile snippet.
- `## Methodology` must include the `Benchmark matrices:` table.
- `## Methodology` must include the `Database pool policy used by the benchmark:` list.
- `## Workloads` must be a Markdown table, not bullets.
- Stress completion cells must be written as completed/planned fractions such as `10/10`, not bare counts.
- Async::Job table throughput cells must include the ` jobs/s` unit.

Required document skeleton:

1. `# Solid Queue Bench`
2. Short introduction:
   - One paragraph: "This repo benchmarks Solid Queue `fiber` and `thread` execution modes across Rails job shapes that wait, stream, talk to the database, and burn CPU."
   - One paragraph defining `concurrency = N` and `processes`, including the 10 x 6 = 60 example.
   - Result date, Ruby version, isolation level, and Solid Queue revision when supplied.
   - Artifact links in one sentence using these link labels: `results`, `Solid Queue`, `Async::Job`, `stress`.
3. `## Research Questions`
4. `## Methodology`
   - One opening paragraph describing the four public views and, if supplied, the separate pool-policy suite.
   - The supplied methodology bullets.
   - One representative-run sentence.
   - `Benchmark matrices:` followed by the fixed benchmark matrix table.
   - `Database pool policy used by the benchmark:` followed by the supplied DB pool policy bullets.
5. `## Headline Results`
   - `### Method`
   - Headline chart embeds/links from the facts.
   - Fixed headline table.
   - `### Interpretation`
6. `## DB Workloads`
   - `### Method`
   - Fixed DB table.
   - One precise DB transaction matched-pool note.
   - DB chart embeds/links from the facts.
   - `### Interpretation`
7. `## Stress Suite`
   - `### Method`
   - Stress status chart only.
   - Fixed stress completion table.
   - `### Interpretation`
8. `## Async::Job Comparison`
   - `### Method`
   - Fixed Async::Job table.
   - `### Interpretation`
9. `## Workloads`
10. `## Setup`
11. `## Running`
12. `## Caveats`

Fixed headline table schema:

| Workload | Tests | Best Throughput | Lowest RSS | Lowest CPU | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta |
|---|---:|---|---|---|---|---:|---:|

For cells in that table, use the established compact style:

- Best Throughput: `fiber, c=10, proc=6, 511.58 jobs/s`
- Lowest RSS: `fiber, c=5, proc=1, 134.34 MB`
- Lowest CPU: `fiber, c=5, proc=1, 95.20%`
- Lowest p50 Latency: `fiber, c=10, proc=6, 2303.85 ms`
- Avg Fiber Throughput Delta: `+5.9% across 9 cells`
- Best Fiber Throughput Delta: `+20.4% at c=50, proc=1`

Fixed DB table schema:

| Workload | Shape | Best Throughput | Lowest RSS | Lowest CPU | Lowest p50 Latency | Avg Fiber Throughput Delta | Best Fiber Throughput Delta |
|---|---|---|---|---|---|---:|---:|

Use the workload shape from the supplied workload facts. Cover only `db_queries`, `db_mixed`, and `db_transaction`. Do not include `db_transaction_pool_pressure`.

Fixed benchmark matrix table schema:

| Suite | Workloads | Concurrencies | Processes | Modes | Repeat | Max total concurrency |
|---|---|---|---|---|---:|---|

Fixed workloads table schema:

| Workload | Shape | Purpose |
|---|---|---|

Fixed stress table schema:

| Workload | Fiber Cells | Thread Cells |
|---|---:|---:|

Each stress row must use completed/planned values, for example:

| Sleep | 10/10 | 1/10 |

Fixed Async::Job table schema:

| Workload | Solid Queue Fiber Best | Async::Job Best | Async::Job Delta |
|---|---:|---:|---:|

The first two numeric cells must include ` jobs/s`, for example:

| Sleep | 511.58 jobs/s | 635.94 jobs/s | +24.3% |

Content rules:

- No hype and no claims beyond the supplied facts.
- Use exact numbers from the facts. Round percentages and numeric metrics to one decimal or two decimals where that reads better.
- Report both average fiber throughput delta and best fiber throughput delta when both are available.
- The `## Headline Results` section is only for `sleep`, `async_http`, `ruby_llm_stream`, and `cpu`.
- Keep the DB workload framing precise: primary Solid Queue DB results are the fair executor/runtime comparison when the DB pool is matched for both modes.
- Treat mode-specific or mismatched DB pool runs as a separate pool-sizing question, not as the primary executor comparison.
- Do not use `db_transaction_pool_pressure` in the public README headline, DB, workload, or caveat sections. Ignore it even if it appears elsewhere in the facts.
- Be explicit that Async::Job changes the backend, so it is a throughput-ceiling reference, not the same comparison as Solid Queue fiber vs thread.
- Treat the stress suite as a current Solid Queue implementation/design failure-envelope test under high connection demand, not as a fundamental thread-vs-fiber law.
- When relevant, note that capped suites intentionally omit cells above the max total concurrency cap, so higher concurrencies may show only `1 proc` results.
- If multiple headline chart facts are supplied, include them in the Headline Results method section, but keep the section shape unchanged.
- When Solid Queue fiber-vs-thread charts include RSS, CPU, or latency deltas, mention once that positive percentages mean movement in fiber's favor.
- For the stress section, explain what the status chart means and why completion matters more than throughput there.
- In `## Running`, include the supplied `bin/report` command and the supplied note about single-workload sweeps when present.
- Mention that `bin/report` uses RubyLLM for the public README and narrative when `OPENAI_API_KEY` is set.

Setup and Running shape:

- `## Setup` starts with one `Requirements:` sentence.
- Then include "The Gemfile currently pins Solid Queue as:" followed by a `ruby` code fence containing the supplied Gemfile line.
- Then include one `bash` code fence with the supplied setup commands.
- Then include the supplied setup notes as plain paragraphs.
- `## Running` starts with one `bash` code fence with the supplied sweep commands.
- Then include the single-workload note.
- Then include "Regenerate the public README, result summaries, charts, and narrative from existing artifacts:" followed by one `bash` code fence with the supplied report command.

Use these links exactly where useful:

- `results/README.md`
- `results/solid-queue/README.md`
- `results/async-job/README.md`
- `results/solid-queue-stress/README.md`

For charts, prefer Markdown image embeds when a chart fact has `embeddable: true`, using the provided `path` exactly. Otherwise use a normal Markdown link.
