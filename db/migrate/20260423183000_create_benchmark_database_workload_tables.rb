class CreateBenchmarkDatabaseWorkloadTables < ActiveRecord::Migration[8.1]
  def change
    create_table :benchmark_data_points do |t|
      t.integer :account_key, null: false
      t.integer :bucket, null: false
      t.integer :sequence, null: false
      t.integer :amount_cents, null: false
      t.integer :quantity, null: false
      t.boolean :flagged, null: false, default: false
      t.string :category, null: false
      t.timestamps
    end

    add_index :benchmark_data_points, [ :account_key, :bucket, :sequence ], name: "index_benchmark_data_points_on_account_bucket_sequence"
    add_index :benchmark_data_points, [ :bucket, :category ], name: "index_benchmark_data_points_on_bucket_and_category"

    create_table :benchmark_write_events do |t|
      t.references :benchmark_execution, null: false, foreign_key: true
      t.integer :write_index, null: false
      t.integer :account_key, null: false
      t.integer :bucket, null: false
      t.integer :matched_rows, null: false, default: 0
      t.bigint :total_amount_cents, null: false, default: 0
      t.integer :total_quantity, null: false, default: 0
      t.integer :http_delay_ms
      t.timestamps
    end

    add_index :benchmark_write_events, [ :benchmark_execution_id, :write_index ], unique: true
  end
end
