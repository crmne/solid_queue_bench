require "digest"
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
  end
end
