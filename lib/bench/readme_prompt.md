You are writing the root README for a Rails benchmark repository.

Audience: Rails developers deciding whether Solid Queue fiber execution mode is a good fit.

Write a polished, human-readable Markdown README from the facts provided. Return only Markdown, with no code fences around the whole document.

Style:

- Direct, clear, and pragmatic.
- Same spirit as a strong Rails README: research question first, then methodology, then results, then how to run it.
- No hype and no claims beyond the supplied facts.
- Use exact numbers from the facts. Round percentages and numeric metrics to one decimal or two decimals where that reads better.
- Keep the DB transaction framing precise: matched-pool transaction results answer fair executor/runtime comparison; default-pool transaction pressure results answer database pool sizing pressure.
- Be explicit that Async::Job changes the backend, so it is a throughput-ceiling reference, not the same comparison as Solid Queue fiber vs thread.

Required structure:

1. `# Solid Queue Bench`
2. A short introduction explaining the benchmark and latest checked-in result date.
3. `## Research Questions`
4. `## Headline Results`, with the headline chart links or image links from the facts.
5. A Solid Queue results table covering throughput, memory, latency, and best fiber throughput delta.
6. `## DB Workloads`, with the DB-specific interpretation and the DB chart links if available.
7. `## Stress Suite`, explaining the connection-pool ceiling test and showing the stress chart links.
8. `## Async::Job Comparison`
9. `## Methodology`
10. `## Workloads`
11. `## Setup`
12. `## Running`
13. `## Caveats`

Include these links exactly where useful:

- `results/README.md`
- `results/index.html`
- `results/solid-queue/README.md`
- `results/async-job/README.md`
- `results/solid-queue-stress/README.md`

For charts, prefer Markdown image embeds when a chart fact has `embeddable: true`, using the provided `path` exactly. Otherwise use a normal Markdown link.

Use the supplied `setup` and `running` facts for setup and command sections. Do not invent prerequisites or commands.

Mention that `bin/report` uses RubyLLM for the public README and narrative when `OPENAI_API_KEY` is set.
