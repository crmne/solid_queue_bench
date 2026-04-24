# Narrative Report

Generated without an LLM. Set `OPENAI_API_KEY` and rerun `bin/report` to produce the prose narrative.

## Solid Queue

- Async::HTTP: tests 18/18, best fiber delta +26.0% at c=5, proc=2.
- CPU: tests 18/18, best fiber delta +5.1% at c=10, proc=6.
- DB Mixed: tests 18/18, best fiber delta +18.0% at c=25, proc=2.
- DB Queries: tests 18/18, best fiber delta +16.9% at c=25, proc=1.
- DB Transaction: tests 18/18, best fiber delta +24.6% at c=50, proc=1.
- RubyLLM Stream: tests 18/18, best fiber delta +20.2% at c=10, proc=2.
- Sleep: tests 18/18, best fiber delta +27.2% at c=10, proc=2.

## Async::Job

- Async::HTTP: tests 9/9, best fiber delta n/a.
- CPU: tests 9/9, best fiber delta n/a.
- RubyLLM Stream: tests 9/9, best fiber delta n/a.
- Sleep: tests 9/9, best fiber delta n/a.

## Solid Queue Stress

- Async::HTTP: tests 11/20, best fiber delta +5.6% at c=25, proc=2.
- RubyLLM Stream: tests 11/20, best fiber delta +7.4% at c=25, proc=2.
- Sleep: tests 11/20, best fiber delta +9.4% at c=25, proc=2.
