class RunInvestigationJob < ApplicationJob
  queue_as :default

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You're investigating an idea for a senior engineer. They've written
    a note and want you to explore it deeply.

    Use whatever tools help:
    - For codebase questions, read the actual repos in the working directory.
    - For org context, use the MCP tools available (Jira, Confluence, GitHub,
      etc. — whatever the user has configured).
    - For conceptual ideas, reason directly.

    Structure your final report:
    - Understanding: what the idea is actually asking.
    - Evidence: what you found (with file paths, Jira keys, URLs - cite everything).
    - Approaches: 2-3 concrete options with trade-offs.
    - Next steps: what would sharpen this further.

    Ground claims in what you actually found or read. Don't invent.
  PROMPT

  def perform(investigation_id)
    @investigation = Investigation.find_by(id: investigation_id)
    return unless @investigation

    idea = @investigation.idea
    mark_running(@investigation)

    @conversation = idea.user.conversations.create!(
      title: "Investigation — #{idea.title.truncate(40)} — #{Time.current.to_date.strftime('%d %b')}"
    )
    prompt_text = build_prompt(idea, @investigation)
    @conversation.messages.create!(role: "user", content: prompt_text)

    result = ClaudeCodeRunner.new.run(prompt: prompt_text, system_prompt: system_prompt_with_mode(@investigation))

    if result[:text].present?
      @conversation.messages.create!(role: "assistant", content: result[:text])
      @investigation.update!(status: "done", conversation_id: @conversation.id)
      broadcast(@investigation)
    else
      @conversation.destroy
      @conversation = nil
      mark_failed(@investigation, result[:error] || "unknown error")
    end
  rescue => e
    Rails.logger.error "[RunInvestigationJob] #{e.class}: #{e.message}"
    @conversation&.destroy
    mark_failed(@investigation, "#{e.class}: #{e.message}") if @investigation&.persisted?
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"]
  end

  private

  def mark_running(inv)
    inv.update!(status: "running")
    broadcast(inv)
  end

  def mark_failed(inv, message)
    inv.update!(status: "failed", error_message: message.to_s[0, 1000])
    broadcast(inv)
  end

  def broadcast(inv)
    Turbo::StreamsChannel.broadcast_replace_to(
      "idea_#{inv.idea_id}",
      target: "investigation_#{inv.id}",
      partial: "investigations/summary",
      locals: { investigation: inv }
    )
  end

  def build_prompt(idea, investigation)
    parts = [
      "IDEA: #{idea.title}",
      "",
      "NOTES:",
      idea.body.presence || "(no notes yet)"
    ]
    if investigation.prompt.present?
      parts << ""
      parts << "STEERING: #{investigation.prompt}"
    end
    parts.join("\n")
  end

  def system_prompt_with_mode(investigation)
    suffix = Skills::InvestigationModes.suffix_for(investigation.mode)
    suffix.empty? ? SYSTEM_PROMPT : "#{SYSTEM_PROMPT}\n\n#{suffix}"
  end
end
