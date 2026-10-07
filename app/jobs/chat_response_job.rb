class ChatResponseJob < ApplicationJob
  def perform(chat_id, content, api_base = nil)
    chat = Chat.find(chat_id)
    if api_base
      chat.with_context(RubyLLM.context do |config|
        config.openai_api_base = api_base
        config.openai_api_key = "benchmark-openai-key"
        config.openai_protocol = :chat_completions
        config.faraday_adapter = Bench::Workloads.llm_adapter
      end)
    end

    chat.ask(content) do |chunk|
      if chunk.content && !chunk.content.empty?
        message = chat.messages.last
        message.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
