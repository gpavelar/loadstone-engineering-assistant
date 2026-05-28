class Idea < ApplicationRecord
  belongs_to :user
  has_many :investigations, dependent: :destroy

  validates :title, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def append_to_body!(text)
    stripped_body = body.to_s.strip
    new_body = stripped_body.empty? ? text : "#{stripped_body}\n\n#{text}"
    update!(body: new_body)
  end
end
