module Skills
  module InvestigationModes
    MODES = {
      "research" => {
        label: "Research",
        steering: "Understand the space. Map sources of truth, find open questions, surface unknowns. Don't propose solutions yet.",
        prompt_suffix: <<~SUFFIX.freeze
          ## Mode: Research

          Structure the report as:
          - Understanding (what the user is asking)
          - Evidence (what you found, with citations)
          - Open Questions (what's still unclear or worth investigating further)

          Do NOT include an Approaches section. Stay descriptive — solutions are out of scope for this mode.
        SUFFIX
      },
      "plan" => {
        label: "Plan",
        steering: "Translate the idea into a sequenced plan. Identify milestones, dependencies, risks.",
        prompt_suffix: <<~SUFFIX.freeze
          ## Mode: Plan

          Structure the report as:
          - Goal (what we're trying to achieve)
          - Milestones (ordered, each ~1 week of work or less)
          - Dependencies (other teams, systems, decisions)
          - Risks (what could go wrong + mitigation)
          - Suggested first step (concrete action for this week)
        SUFFIX
      },
      "compare" => {
        label: "Compare",
        steering: "Compare the options. Surface tradeoffs concretely. Recommend one.",
        prompt_suffix: <<~SUFFIX.freeze
          ## Mode: Compare

          Structure the report as:
          - Options (one section per option being compared)
          - Tradeoffs table (rows: each option; columns: cost, risk, speed, maintainability, fit-with-existing)
          - Recommendation (one option, with reasoning grounded in the tradeoffs above)
        SUFFIX
      },
      "spec" => {
        label: "Spec",
        steering: "Produce a Technical RFC-shaped output ready to lift into a doc.",
        prompt_suffix: <<~SUFFIX.freeze
          ## Mode: Spec

          Structure the report as a Technical RFC:
          - Problem (what's broken / missing / inefficient today)
          - Goals (what success looks like — measurable when possible)
          - Non-goals (explicit scope boundaries)
          - Approaches considered (at least 2, with tradeoffs)
          - Decision (chosen approach with rationale)
          - Open questions (calls for follow-up)

          Cite all evidence with file paths and Jira keys. This output will be lifted into a Confluence RFC verbatim.
        SUFFIX
      }
    }.freeze

    def self.suffix_for(mode_value)
      return "" if mode_value.blank?
      MODES.fetch(mode_value.to_s, {})[:prompt_suffix].to_s
    end

    def self.steering_for(mode_value)
      return "" if mode_value.blank?
      MODES.fetch(mode_value.to_s, {})[:steering].to_s
    end

    def self.label_for(mode_value)
      return "Default" if mode_value.blank?
      MODES.fetch(mode_value.to_s, {})[:label] || "Default"
    end

    def self.valid?(mode_value)
      mode_value.blank? || MODES.key?(mode_value.to_s)
    end
  end
end
