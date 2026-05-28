class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy
  has_many :investigations, dependent: :nullify

  # Derived from Skills::Registry — adding a skill never requires editing this file.
  # "general" is included as a sentinel for messages with no slash command.
  def self.skill_label_for(skill_name)
    return nil if skill_name.blank? || skill_name.to_s == "general"
    Skills::Registry.labels[skill_name.to_s]
  end

  # Backwards-compatible accessor mirroring the previous SKILL_LABELS hash.
  SKILL_LABELS = Hash.new { |_, key| Conversation.skill_label_for(key) }.freeze

  def set_title_from_first_message!
    first_msg = messages.where(role: "user").order(:created_at).first
    return unless first_msg

    content = first_msg.content.strip
    command = content.split(/\s/, 2).first.to_s.downcase
    skill = Skills::Registry.find_by_command(command)

    new_title = if skill
      skill.title_for(content)
    else
      content.truncate(50)
    end

    update!(title: new_title)
  end
end
