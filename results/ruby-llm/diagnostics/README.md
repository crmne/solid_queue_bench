# Repeated-call slowdown investigation

The pinned main revision does extra work: it persists a usage-ledger row for each plain chat request in Rails. RubyLLM 2.0 does not. Development-mode SQL logging adds a backtrace for each database statement. The original repeated-call result is a valid measurement of these defaults, but does not isolate HTTP or connection-reuse performance.

These controls retain the original workload: 50 jobs, 20 new-chat calls per job, five threads, one Solid Queue worker, matched DB pool, default `net_http`, and three repetitions. All calls use the same local fake endpoint. All 15 repetitions completed 50/50 jobs and 1,000 requests. The 2.0 and main dependency locks are unchanged.

| Configuration | Median jobs/s | Three repetitions | Usage rows per 1,000 calls |
|---|---:|---|---:|
| [2.0 defaults](2.0-default.json) | 37.32 | 37.15, 37.32, 38.63 | 0 |
| [Main defaults](main-default.json) | 19.07 | 18.53, 19.07, 19.31 | 1,000 |
| [Main, ledger disabled diagnostically](main-no-ledger.json) | 60.55 | 57.40, 60.55, 62.19 | 0 |
| [Main, verbose SQL backtraces disabled](main-quiet-sql.json) | 35.88 | 34.32, 35.88, 36.35 | 1,000 |
| [2.0, verbose SQL backtraces disabled](2.0-quiet-sql.json) | 41.52 | 41.35, 41.52, 41.77 | 0 |

Disabling only main's ledger makes it 62% faster than 2.0 in this control. Turning off verbose SQL backtraces while retaining the ledger nearly doubles main's throughput; it remains 14% below 2.0 with the same logging setting. Thus logging amplifies the additional persistence cost, but does not account for all of it. These are diagnostic controls, not recommendations to disable accounting. They do not replace the default-configuration results.

## CPU evidence

Separate StackProf CPU profiles covered 200 jobs / 4,000 requests per version, starting with the first workload call inside the worker. They include queue work after that point. Profiled runs are separate from the throughput measurements above. [Sample summaries](cpu-profiles.json) retain sample counts and the busiest methods.

On main, `RubyLLM::ActiveRecord::Usage.record` appeared in 5,590 of 8,736 CPU samples (64%). `ActiveRecord::LogSubscriber#log_query_source` appeared in 3,743 (43%), and `ActiveSupport::BacktraceCleaner#first_clean_frame` in 3,623 (41%). These are inclusive, overlapping counts, not additive percentages. The profiled main run left exactly 4,000 usage rows without chat associations.

The source explains the difference: main's Railtie installs `RubyLLM::ActiveRecord::Usage` as `RubyLLM::Accounting::Usage.ledger` when Active Record loads. Plain chats call that ledger, whose `record` method creates a row in a transaction. The 2.0 accounting implementation has no standalone ledger. This behavior accompanies 2.1's support for tracking usage outside persisted chats.

A preliminary warmed-up serial profile appeared faster on main, but it had not loaded Active Record and therefore had not installed the ledger. That contrast led to the queued profiles; the serial result is not an equivalent Rails workload and is not used in the table.

## Reproduce

From the repository root, with the same database and Redis setup as the main benchmark:

```sh
DB_USER=postgres script/profile_rubyllm_requests --output tmp/request-diagnostics
```

To also collect worker CPU dumps, install StackProf separately from the benchmark bundles and add `--profile`. `--only main-no-ledger` selects one control. The script creates an environment-gated temporary Rails initializer and removes it when finished. Ledger disabling uses an internal API solely to establish causality. No framework checkout, dependency lock, or normal application setting is changed.

## Interpretation

Keep the original result, explicitly labeled as including main's new usage persistence. Use the ledger-disabled control to discuss equivalent-work request overhead. For deployment guidance, measure with the application's actual logging and accounting configuration; disabling verbose query logs here alone is not a complete production-mode benchmark. No TLS or wide-area-network latency was simulated, and the profiles do not establish a real-network latency benefit from reuse.
