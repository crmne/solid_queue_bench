require "async/job/processor/redis"
require "async/redis/endpoint"
require Rails.root.join("lib/bench/async_job/concurrency_limiter")

Rails.application.configure do
  redis_config = Rails.application.config_for(:redis).with_indifferent_access

  endpoint = Async::Redis::Endpoint.remote(
    redis_config.fetch(:host),
    Integer(redis_config.fetch(:port))
  ).with(
    database: Integer(redis_config.fetch(:db)),
    password: redis_config[:password]
  )

  queue_capacity = Integer(ENV.fetch("BENCH_CAPACITY", "100"))
  queue_prefix = redis_config.fetch(:prefix)

  %w[default solid_queue_recurring].each do |queue_name|
    config.async_job.define_queue queue_name do
      dequeue Async::Job::Processor::Redis, endpoint:, prefix: queue_prefix
      dequeue Bench::AsyncJob::ConcurrencyLimiter, limit: queue_capacity
    end
  end
end
