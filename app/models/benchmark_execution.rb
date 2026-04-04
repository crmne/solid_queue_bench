class BenchmarkExecution < ApplicationRecord
  belongs_to :benchmark_run

  scope :finished, -> { where.not(finished_at: nil) }
  scope :successful, -> { finished.where(error_class: nil) }
  scope :failed, -> { where.not(error_class: nil) }
end
