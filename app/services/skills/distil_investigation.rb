module Skills
  class DistilInvestigation
    Result = Struct.new(:success?, :section, :error, keyword_init: true)

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You distil one investigation report into a Markdown section that will be appended
      to a research note. The note grows by accretion — future readers will scan these
      sections and may lift them into a Technical RFC.

      ## Output Format (FOLLOW EXACTLY)

      Output ONLY the Markdown section below — no preamble, no closing remarks.

      ## Findings — <DD MMM> · "<steering text, truncated to 60 chars>"

      <1-2 sentence TL;DR of the core finding.>

      **Evidence**
      - <bullet — preserve file paths / Jira keys / URLs verbatim from the report>
      - <bullet>

      **Approaches considered**
      - <label>: <option> — <key tradeoff>

      **Suggested next:** <1-2 sentence pointer for what to do or revisit.>

      ## Rules

      - Total length ~150-300 words. Terse.
      - Preserve all concrete citations (file paths, Jira keys, URLs) from the report.
      - If steering is "(none)", use the date alone in the header: `## Findings — 7 May`.
      - DON'T invent. If a section has no content in the report, omit it entirely.
      - DON'T editorialize beyond what the report says.
      - DON'T re-summarize the report's "Understanding" section — start directly with the TL;DR.
    PROMPT

    def initialize(investigation)
      @investigation = investigation
    end

    def call
      report = @investigation.conversation
                             &.messages
                             &.where(role: "assistant")
                             &.last
                             &.content
      return failure("Investigation has no report") if report.blank?

      response = AgentService.new(system_prompt: SYSTEM_PROMPT, model: :haiku)
                             .chat(
                               messages: [ { role: "user", content: build_user_prompt(report) } ],
                               tools: []
                             )

      section = response[:content].to_s.strip
      return failure("Empty response from agent") if section.blank?

      Result.new(success?: true, section: section_with_link(section))
    rescue => e
      Rails.logger.error "[DistilInvestigation] #{e.class}: #{e.message}"
      failure("#{e.class}: #{e.message[0, 200]}")
    end

    private

    def failure(msg)
      Result.new(success?: false, error: msg)
    end

    def section_with_link(section)
      path = Rails.application.routes.url_helpers.conversation_path(@investigation.conversation)
      "#{section}\n\n[Full investigation →](#{path})"
    end

    def build_user_prompt(report)
      <<~PROMPT
        IDEA TITLE: #{@investigation.idea.title}

        INVESTIGATION DATE: #{@investigation.created_at.strftime('%-d %b')}
        STEERING: #{@investigation.prompt.presence || "(none)"}

        INVESTIGATION REPORT:
        #{report}
      PROMPT
    end
  end
end
