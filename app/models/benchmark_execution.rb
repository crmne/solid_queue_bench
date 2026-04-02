class BenchmarkExecution < ApplicationRecord
  belongs_to :benchmark_run

  scope :completed, -> { where.not(finished_at: nil) }
  scope :failed, -> { where.not(error_class: nil) }
end
