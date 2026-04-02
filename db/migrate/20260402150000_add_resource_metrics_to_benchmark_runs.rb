class AddResourceMetricsToBenchmarkRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :benchmark_runs, :avg_rss_kb, :integer
    add_column :benchmark_runs, :avg_cpu_pct, :float
    add_column :benchmark_runs, :peak_cpu_pct, :float
  end
end
