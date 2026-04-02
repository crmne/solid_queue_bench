class CreateBenchmarkRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :benchmark_runs do |t|
      t.string :name, null: false
      t.string :execution_mode, null: false
      t.string :workload, null: false
      t.integer :capacity, null: false
      t.integer :processes, null: false
      t.integer :jobs_count, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :started_at
      t.datetime :enqueued_at
      t.datetime :completed_at
      t.float :wall_time_s
      t.float :jobs_per_second
      t.integer :peak_rss_kb
      t.text :notes
      t.timestamps
    end
  end
end
