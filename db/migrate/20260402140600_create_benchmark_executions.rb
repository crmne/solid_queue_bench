class CreateBenchmarkExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :benchmark_executions do |t|
      t.references :benchmark_run, null: false, foreign_key: true
      t.integer :job_index, null: false
      t.string :workload, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :active_job_id
      t.integer :worker_pid
      t.datetime :enqueued_at, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.string :error_class
      t.text :error_message
      t.timestamps
    end

    add_index :benchmark_executions, [ :benchmark_run_id, :job_index ], unique: true
    add_index :benchmark_executions, :active_job_id
  end
end
