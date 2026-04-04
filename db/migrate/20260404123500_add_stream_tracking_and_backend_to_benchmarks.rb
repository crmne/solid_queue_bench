class AddStreamTrackingAndBackendToBenchmarks < ActiveRecord::Migration[8.1]
  def change
    add_column :benchmark_runs, :backend, :string, null: false, default: "solid_queue"

    add_column :benchmark_executions, :child_jobs_enqueued, :integer, null: false, default: 0
    add_column :benchmark_executions, :child_jobs_finished, :integer, null: false, default: 0
    add_column :benchmark_executions, :child_jobs_failed, :integer, null: false, default: 0
    add_column :benchmark_executions, :last_child_enqueued_at, :datetime
    add_column :benchmark_executions, :last_child_finished_at, :datetime

    add_reference :chats, :benchmark_execution, foreign_key: true
  end
end
