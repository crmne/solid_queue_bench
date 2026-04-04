class BroadcastJob < ApplicationJob
  queue_as :default

  def perform(benchmark_execution_id, message_id: nil, content: nil, benchmark_run_id: nil)
    if message_id
      message = Message.find(message_id)
      message.broadcast_append_to(
        "chat_#{message.chat_id}",
        target: "message_#{message.id}_content",
        content: ERB::Util.html_escape(content.to_s)
      )
    elsif benchmark_run_id
      BenchmarkRun.where(id: benchmark_run_id).update_all(
        "notes = COALESCE(notes, '') || 'b'"
      )
    end

    Bench::Broadcasts.mark_finished!(benchmark_execution_id)
  rescue StandardError
    Bench::Broadcasts.mark_failed!(benchmark_execution_id)
    raise
  end
end
