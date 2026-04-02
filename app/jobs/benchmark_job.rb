class BenchmarkJob < ApplicationJob
  queue_as :default

  def perform(benchmark_execution_id)
    started_at = nil
    execution = BenchmarkExecution.find(benchmark_execution_id)
    started_at = Time.current

    Bench::Workloads.call(
      execution.workload,
      execution.payload.deep_symbolize_keys
    )

    execution.update_columns(
      started_at: started_at,
      finished_at: Time.current,
      worker_pid: Process.pid
    )
  rescue StandardError => error
    execution&.update_columns(
      started_at: started_at,
      finished_at: Time.current,
      worker_pid: Process.pid,
      error_class: error.class.name,
      error_message: error.message
    )
    raise
  end
end
