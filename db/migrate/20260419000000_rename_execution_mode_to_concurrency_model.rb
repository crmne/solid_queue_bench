class RenameExecutionModeToConcurrencyModel < ActiveRecord::Migration[8.1]
  def change
    rename_column :benchmark_runs, :execution_mode, :concurrency_model
    rename_column :benchmark_runs, :capacity, :concurrency

    reversible do |dir|
      dir.up do
        execute "UPDATE benchmark_runs SET concurrency_model = 'fiber' WHERE concurrency_model = 'async'"
      end
      dir.down do
        execute "UPDATE benchmark_runs SET execution_mode = 'async' WHERE execution_mode = 'fiber'"
      end
    end
  end
end
