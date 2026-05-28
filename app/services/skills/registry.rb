module Skills
  # Single source of truth for the slash-command-driven skills.
  #
  # Adding a skill = define one class that `extend Skills::Base` and add it to
  # SKILL_CLASSES below. SkillRouter, Conversation labels/titles, /help text,
  # and the chat palette all derive from this registry.
  class Registry
    SKILL_CLASSES = [
      Skills::Compass,
      Skills::Journal,
      Skills::Blockers,
      Skills::Stakeholders,
      Skills::BoardHygiene,
      Skills::Retro,
      Skills::Prep,
      Skills::Onboard,
      Skills::Handover,
      Skills::Deadcode,
      Skills::Duplicates,
      Skills::Checkin,
      Skills::PlanningGap,
      Skills::Help
    ].freeze

    def self.all
      SKILL_CLASSES
    end

    def self.find_by_command(command)
      return nil if command.blank?
      normalized = command.to_s.downcase
      SKILL_CLASSES.find { |s| s.command == normalized }
    end

    def self.commands
      SKILL_CLASSES.map(&:command)
    end

    # Hash from skill_name (string) to label, used by Conversation for the
    # sidebar. General is added externally — it's not a registered skill.
    def self.labels
      SKILL_CLASSES.to_h { |s| [s.skill_name.to_s, s.label] }
    end

    # JSON-friendly entries for the chat autocomplete palette.
    def self.palette_entries
      SKILL_CLASSES.map { |s| { cmd: s.command, desc: s.description } }
    end

    # Markdown table rendered into /help output.
    def self.help_markdown
      rows = SKILL_CLASSES.map { |s| "| `#{s.command}` | #{s.description} |" }
      <<~HELP
        | Command | What it does |
        |---------|-------------|
        #{rows.join("\n")}
      HELP
    end
  end
end
