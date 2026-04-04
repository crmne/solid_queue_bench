class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :benchmark_execution, optional: true
end
