class SkillRouter
  def self.route(input)
    command = input.to_s.strip.split(/\s/, 2).first.to_s.downcase
    skill = Skills::Registry.find_by_command(command)

    if skill
      {
        skill: skill.skill_name,
        system_prompt: skill.system_prompt,
        user_input: input.sub(command, "").strip,
        model: skill.model
      }
    else
      {
        skill: :general,
        system_prompt: Skills::General.system_prompt,
        user_input: input,
        model: :haiku
      }
    end
  end
end
