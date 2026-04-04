require "digest"
require "erb"
require "json"
require "net/http"
require "uri"
require "async/http/internet"

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
        duration_ms = payload.fetch(:duration_ms)
        port = payload.fetch(:port)
        uri = URI("http://127.0.0.1:#{port}/delay?ms=#{duration_ms}")
        response = Net::HTTP.get_response(uri)
        raise "Unexpected response: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      when "async_http"
        async_http_request(payload)
      when "llm_batch"
        duration_s = payload.fetch(:duration_s)
        sleep(duration_s)
      when "llm_stream"
        llm_stream_request(payload)
      when "ruby_llm_stream"
        ruby_llm_stream_request(payload)
      else
        raise ArgumentError, "Unknown workload: #{name}"
      end
    end

    def async_http_request(payload)
      duration_ms = payload.fetch(:duration_ms)
      port = payload.fetch(:port)
      internet = Async::HTTP::Internet.new
      response = internet.get("http://127.0.0.1:#{port}/delay?ms=#{duration_ms}")
      raise "Unexpected response: #{response.status}" unless response.success?

      JSON.parse(response.read)
    ensure
      internet&.close
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

      with_fake_openai_config(port) do
        chat = Chat.create!(
          model: Model.find_by!(provider: "openai", model_id: model_id),
          benchmark_execution_id: benchmark_execution_id
        )

        ChatResponseJob.perform_now(chat.id, prompt)
      end
    end

    def with_fake_openai_config(port)
      previous_api_base = RubyLLM.config.openai_api_base
      previous_api_key = RubyLLM.config.openai_api_key

      RubyLLM.config.openai_api_base = "http://127.0.0.1:#{port}/v1"
      RubyLLM.config.openai_api_key = "benchmark-openai-key"

      yield
    ensure
      RubyLLM.config.openai_api_base = previous_api_base
      RubyLLM.config.openai_api_key = previous_api_key
    end
  end
end
