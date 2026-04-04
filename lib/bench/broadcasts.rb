module Bench
  module Broadcasts
    module_function

    def enqueue!(benchmark_execution_id, message_id: nil, content: nil, benchmark_run_id: nil)
      job = BroadcastJob.new(
        benchmark_execution_id,
        message_id: message_id,
        content: content,
        benchmark_run_id: benchmark_run_id
      )

      job.enqueue
      ensure_enqueued!(job)
      mark_enqueued!(benchmark_execution_id)
      job
    end

    def mark_finished!(benchmark_execution_id)
      update_counter!(
        benchmark_execution_id,
        "child_jobs_finished = child_jobs_finished + 1",
        "last_child_finished_at = :timestamp"
      )
    end

    def mark_failed!(benchmark_execution_id)
      update_counter!(
        benchmark_execution_id,
        "child_jobs_failed = child_jobs_failed + 1",
        "last_child_finished_at = :timestamp"
      )
    end

    def mark_enqueued!(benchmark_execution_id)
      update_counter!(
        benchmark_execution_id,
        "child_jobs_enqueued = child_jobs_enqueued + 1",
        "last_child_enqueued_at = :timestamp"
      )
    end

    def ensure_enqueued!(job)
      return if job.successfully_enqueued?

      message = job.enqueue_error&.message || "unknown enqueue failure"
      raise "Failed to enqueue broadcast job: #{message}"
    end

    def update_counter!(benchmark_execution_id, counter_sql, timestamp_sql)
      now = Time.current

      BenchmarkExecution.where(id: benchmark_execution_id).update_all(
        [
          "#{counter_sql}, #{timestamp_sql}, updated_at = :timestamp",
          { timestamp: now }
        ]
      )
    end
  end
end
