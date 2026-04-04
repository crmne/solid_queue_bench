class BroadcastJob < ApplicationJob
  queue_as :default

  def perform(benchmark_run_id)
    # Minimal work -- simulates a Turbo::Streams::ActionBroadcastJob
    # that renders a partial and broadcasts to a channel.
    # We just touch a counter so the work isn't optimized away.
    BenchmarkRun.where(id: benchmark_run_id).update_all(
      "notes = COALESCE(notes, '0') || 'b'"
    )
  end
end
