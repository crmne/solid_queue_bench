require "open3"
require "socket"
require "async"
require "async/redis/client"

module Bench
  module AsyncJob
    class RedisService
      CONTAINER_NAME = "solid-queue-bench-redis"
      IMAGE = "redis:7-alpine"

      def initialize(config = Rails.application.config_for(:redis))
        @config = config.with_indifferent_access
      end

      attr_reader :config

      def ensure_available!
        return if available?

        unless local_host? && docker_available?
          raise "Redis is not reachable at #{host}:#{port}. Start Redis or use local Docker-backed Redis."
        end

        start_container!
        wait_until_available!
      end

      def flushdb!
        endpoint = Async::Redis::Endpoint.remote(host, port).with(database:, password:)
        client = Async::Redis::Client.new(endpoint)

        Async do
          client.call("FLUSHDB")
        ensure
          client.close
        end.wait
      end

      def available?
        Socket.tcp(host, port, connect_timeout: 0.2) { |socket| socket.close }
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        false
      end

      def host
        config.fetch(:host)
      end

      def port
        Integer(config.fetch(:port))
      end

      def database
        Integer(config.fetch(:db))
      end

      def password
        config[:password]
      end

      private

      def local_host?
        %w[127.0.0.1 localhost].include?(host)
      end

      def docker_available?
        system("docker", "info", out: File::NULL, err: File::NULL)
      end

      def start_container!
        remove_existing_container!

        args = [
          "docker", "run", "-d", "--rm",
          "--name", CONTAINER_NAME,
          "-p", "#{port}:6379",
          IMAGE,
          "redis-server", "--save", "", "--appendonly", "no"
        ]

        run!(*args)
      end

      def remove_existing_container!
        system("docker", "rm", "-f", CONTAINER_NAME, out: File::NULL, err: File::NULL)
      end

      def wait_until_available!(timeout: 5.0)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

        until available?
          raise "Redis did not start on #{host}:#{port}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep 0.05
        end
      end

      def run!(*command)
        output, status = Open3.capture2e(*command)
        return output if status.success?

        raise output.strip
      end
    end
  end
end
