RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"].presence || "benchmark-openai-key"
  config.openai_protocol = :chat_completions
end
