class Investigation < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  belongs_to :idea
  belongs_to :conversation, optional: true

  enum :status, STATUSES.index_with(&:itself), validate: { presence: true }
end
