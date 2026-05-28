class Message < ApplicationRecord
  belongs_to :conversation
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
end
