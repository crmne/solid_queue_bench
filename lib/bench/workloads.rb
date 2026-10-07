require "digest"
require "erb"
require "json"
require "net/http"
require "uri"
require "async"
require "async/http/internet"
require "bench/database_workload"

module Bench
  module Workloads
    module_function

    def call(name, payload)
      case name.to_s
      when "sleep"
        sleep(payload.fetch(:duration_ms).to_f / 1000.0)
      when "cpu"
        cpu_iterations = payload.fetch(:iterations)
        cpu_iterations.times { |i| Digest::SHA256.hexdigest("#{i}-#{cpu_iterations}") }
      when "http"
        http_request(payload)
      when "async_http"
        async_http_request(payload)
      when "llm_batch"
        duration_s = payload.fetch(:duration_s)
        sleep(duration_s)
      when "llm_stream"
        llm_stream_request(payload)
      when "ruby_llm_stream"
        ruby_llm_stream_request(payload)
      when "ruby_llm_stream_only"
        chat = llm_context(payload.fetch(:port)).chat(model: payload.fetch(:model_id), provider: :openai)
        chunks = 0
        response = chat.ask(payload.fetch(:prompt)) { |chunk| chunks += 1 if chunk.content && !chunk.content.empty? }
        raise "Incomplete stream: #{chunks} chunks" unless chunks == payload.fetch(:token_count)
        raise "Incorrect streamed usage" unless response.tokens.output == payload.fetch(:token_count)
      when "ruby_llm_history"
        payload.fetch(:rebuilds).times do
          chat = Chat.find(payload.fetch(:chat_id)).to_llm
          raise "Incomplete persisted history" unless chat.messages.size == payload.fetch(:history_messages)
        end
      when "ruby_llm_requests"
        context = llm_context(payload.fetch(:port))
        payload.fetch(:calls).times do
          # A fresh chat each time exercises sharing between chats as well as jobs.
          response = context.chat(model: payload.fetch(:model_id), provider: :openai).ask(payload.fetch(:prompt))
          raise "Incomplete response" unless response.content.split.size == payload.fetch(:token_count)
        end
      when "db_queries"
        Bench::DatabaseWorkload.db_queries(payload)
      when "db_transaction", "db_transaction_pool_pressure"
        Bench::DatabaseWorkload.db_transaction(payload)
      when "db_mixed"
        Bench::DatabaseWorkload.db_mixed(payload)
      else
        raise ArgumentError, "Unknown workload: #{name}"
      end
    end

    def http_request(payload)
      duration_ms = payload.fetch(:duration_ms)
      port = payload.fetch(:port)
      uri = URI("http://127.0.0.1:#{port}/delay?ms=#{duration_ms}")
      response = Net::HTTP.get_response(uri)
      raise "Unexpected response: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def async_http_request(payload)
      duration_ms = payload.fetch(:duration_ms)
      port = payload.fetch(:port)

      # Thread-mode workers do not run inside an Async task by default, so use
      # Sync to exercise the same client path in both concurrency models.
      Sync do
        internet = Async::HTTP::Internet.new
        response = internet.get("http://127.0.0.1:#{port}/delay?ms=#{duration_ms}")
        raise "Unexpected response: #{response.status}" unless response.success?

        JSON.parse(response.read)
      ensure
        internet&.close
      end
    end

    def llm_stream_request(payload)
      token_count = payload.fetch(:token_count)
      token_delay_ms = payload.fetch(:token_delay_ms)
      benchmark_execution_id = payload.fetch(:benchmark_execution_id)
      benchmark_run_id = payload.fetch(:benchmark_run_id)

      token_count.times do
        sleep(token_delay_ms / 1000.0)
        Bench::Broadcasts.enqueue!(
          benchmark_execution_id,
          benchmark_run_id: benchmark_run_id
        )
      end
    end

    def ruby_llm_stream_request(payload)
      port = payload.fetch(:port)
      benchmark_execution_id = payload.fetch(:benchmark_execution_id)
      model_id = payload.fetch(:model_id)
      prompt = payload.fetch(:prompt)

      chat = Chat.create!(
        model: model_id, provider: :openai,
        benchmark_execution_id: benchmark_execution_id
      )

      ChatResponseJob.perform_now(chat.id, prompt, "http://127.0.0.1:#{port}/v1")
    end

    def llm_adapter
      adapter = ENV.fetch("BENCH_LLM_ADAPTER", "net_http")
      return adapter.to_sym unless adapter == "recommended"

      Fiber.scheduler ? :async_http : :net_http_persistent
    end

    def llm_context(port)
      RubyLLM.context do |config|
        config.openai_api_base = "http://127.0.0.1:#{port}/v1"
        config.openai_api_key = "benchmark-openai-key"
        config.openai_protocol = :chat_completions
        config.faraday_adapter = llm_adapter
      end
    end
  end
end
