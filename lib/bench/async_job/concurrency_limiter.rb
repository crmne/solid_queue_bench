require "async/semaphore"
require "async/job/processor/generic"

module Bench
  module AsyncJob
    class ConcurrencyLimiter < Async::Job::Processor::Generic
      def initialize(delegate, limit:)
        super(delegate)
        @semaphore = Async::Semaphore.new(Integer(limit))
      end

      def call(job)
        @semaphore.acquire { super }
      end
    end
  end
end
