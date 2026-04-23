class BenchmarkJob < ApplicationJob
  queue_as :default

  def perform(benchmark_execution_id)
    started_at = nil
    workload = nil
    payload = nil

    with_benchmark_connection do
      execution = BenchmarkExecution.find(benchmark_execution_id)
      workload = execution.workload
      payload = execution.payload.deep_symbolize_keys
      started_at = Time.current
    end

    clear_active_connections!

    Bench::Workloads.call(
      workload,
      payload.merge(benchmark_execution_id: benchmark_execution_id)
    )

    persist_execution_state!(
      benchmark_execution_id,
      started_at: started_at,
      finished_at: Time.current,
      worker_pid: Process.pid
    )
  rescue StandardError => error
    persist_execution_state(
      benchmark_execution_id,
      started_at: started_at,
      finished_at: Time.current,
      worker_pid: Process.pid,
      error_class: error.class.name,
      error_message: error.message
    )
    raise
  ensure
    clear_active_connections!
  end

  private

  def persist_execution_state!(benchmark_execution_id, **attributes)
    with_benchmark_connection do
      BenchmarkExecution.where(id: benchmark_execution_id).update_all(
        attributes.merge(updated_at: Time.current)
      )
    end
  end

  def persist_execution_state(benchmark_execution_id, **attributes)
    persist_execution_state!(benchmark_execution_id, **attributes)
  rescue StandardError
  end

  def with_benchmark_connection(&block)
    BenchmarkExecution.connection_pool.with_connection(&block)
  end

  def clear_active_connections!
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
end
