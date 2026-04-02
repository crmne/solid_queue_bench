class BenchmarkRun < ApplicationRecord
  has_many :benchmark_executions, dependent: :delete_all

  scope :recent, -> { order(created_at: :desc) }
end
