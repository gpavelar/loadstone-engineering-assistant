module Skills
  # Contract every skill class must satisfy. Concrete skills `extend Skills::Base`
  # so these methods become class-level methods on the skill.
  #
  # Required class methods on each skill:
  #   command         — slash command literal, e.g. "/compass"
  #   skill_name      — symbol used in the database / SKILL_LABELS, e.g. :compass
  #   label           — human-readable label shown in sidebars, e.g. "Daily Compass"
  #   description     — one-line description for the autocomplete palette and /help
  #   model           — :sonnet | :haiku — Anthropic model routing
  #   system_prompt   — the prompt fed to the agent
  #
  # Optional override:
  #   title_for(input) — custom conversation title given the user's full input.
  #                      Default: "<label> — DD MMM"
  module Base
    def title_for(_input)
      default_title
    end

    def default_title
      "#{label} — #{Date.today.strftime('%d %b')}"
    end

    def title_with_optional_arg(input, prefix: nil, fallback: nil, suffix_with_date: false, truncate: 40)
      prefix ||= label
      fallback ||= label
      arg = input.sub(command, "").strip
      if arg.present?
        date_suffix = suffix_with_date ? " — #{Date.today.strftime('%d %b')}" : ""
        "#{prefix} — #{arg.truncate(truncate)}#{date_suffix}"
      else
        suffix_with_date ? "#{fallback} — #{Date.today.strftime('%d %b')}" : fallback
      end
    end
  end
end
