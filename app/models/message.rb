class Message < ApplicationRecord
  acts_as_message

  broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append

  def broadcast_append_chunk(content)
    if chat&.benchmark_execution_id?
      Bench::Broadcasts.enqueue!(
        chat.benchmark_execution_id,
        message_id: id,
        content: content.to_s
      )
    else
      broadcast_append_to "chat_#{chat_id}",
        target: "message_#{id}_content",
        content: ERB::Util.html_escape(content.to_s)
    end
  end
end
