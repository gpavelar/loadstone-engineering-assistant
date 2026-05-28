class MessagesController < ApplicationController
  before_action :set_current_user
  before_action :set_conversation

  def create
    # Save user message
    user_content = params[:content]
    @user_message = @conversation.messages.create!(role: "user", content: user_content)

    # Set conversation title from first message
    @conversation.set_title_from_first_message!

    # Handle /help instantly — no Claude API call needed
    if user_content.strip.downcase == "/help"
      @assistant_message = @conversation.messages.create!(
        role: "assistant",
        content: Skills::Help.help_text,
        skill: "help"
      )
      @conversation.touch
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to conversation_path(@conversation) }
      end
      return
    end

    # Route via SkillRouter
    routed = SkillRouter.route(user_content)

    # Build conversation history
    # Slash commands get CLEAN context — no prior history, just the command.
    # This prevents old compass output polluting a journal call, etc.
    # Natural language follow-ups get full history so conversations flow.
    is_slash_command = user_content.strip.start_with?("/")

    messages = if is_slash_command
                 [{ role: "user", content: user_content }]
               else
                 @conversation.messages.order(:created_at).map do |msg|
                   { role: msg.role, content: msg.content }
                 end
               end

    # Add user context to system prompt
    system_prompt = build_system_prompt(routed[:system_prompt])

    # Create a placeholder assistant message for streaming (with temporary content)
    @assistant_message = @conversation.messages.create!(
      role: "assistant",
      content: "...",
      skill: routed[:skill].to_s,
      tool_calls: {}
    )

    # Touch conversation to update ordering
    @conversation.touch

    # Return the user message + streaming placeholder immediately via Turbo Stream
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end

    # Run the agent in a background thread, streaming results via Turbo Broadcasts
    conversation_id = @conversation.id
    assistant_message_id = @assistant_message.id
    stream_name = "conversation_#{conversation_id}"

    Thread.new do
      Rails.application.executor.wrap do
        begin
          agent = AgentService.new(system_prompt: system_prompt, model: routed[:model])

          on_tool_start = ->(tool_name) {
            broadcast_streaming_status(stream_name, assistant_message_id, "Using #{tool_name.humanize}...")
          }

          last_broadcast_at = Time.now
          result = agent.chat_streaming(messages: messages, on_tool_start: on_tool_start) do |chunk, accumulated_text|
            # Throttle broadcasts to ~20fps to avoid overwhelming ActionCable
            now = Time.now
            if (now - last_broadcast_at) >= 0.05
              broadcast_streaming_chunk(stream_name, assistant_message_id, accumulated_text)
              last_broadcast_at = now
            end
          end

          # Save the final content and tool calls
          msg = Message.find(assistant_message_id)
          msg.update!(content: result[:content], tool_calls: result[:tool_calls])

          # Broadcast the final rendered message (with full markdown)
          broadcast_final_message(stream_name, assistant_message_id, msg)
        rescue => e
          Rails.logger.error "[Loadstone] Streaming error: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
          msg = Message.find_by(id: assistant_message_id)
          if msg
            error_content = "Sorry, something went wrong while generating a response. Please try again."
            msg.update!(content: error_content)
            broadcast_final_message(stream_name, assistant_message_id, msg)
          end
        end
      end
    end
  end

  private

  def set_current_user
    @current_user = User.first
  end

  def set_conversation
    @conversation = @current_user.conversations.find(params[:conversation_id])
  end

  def build_system_prompt(base_prompt)
    user_context = <<~CONTEXT
      ## User Context
      - Name: #{@current_user.name}
      - Jira Account ID: #{@current_user.jira_account_id || 'not set'}
      - GitHub Username: #{@current_user.github_username || 'not set'}
      - Today's Date: #{Date.today.iso8601}
    CONTEXT

    "#{base_prompt}\n\n#{company_context}\n\n#{user_context}"
  end

  def company_context
    @company_context ||= begin
      config = LoadstoneConfig.load("company_context")
      values = config["values"].map { |_k, v| "- **#{v['name']}**: #{v['agent_guidance'].strip}" }.join("\n")
      team = config["team_context"]&.strip
      <<~CONTEXT
        ## Company Context
        Purpose: #{config['purpose']}
        #{team ? "\n#{team}\n" : ""}
        When making recommendations, align with these values:
        #{values}
      CONTEXT
    end
  end

  # Broadcast a streaming text update — replaces the message content with
  # accumulated text so far (rendered as plain text during streaming).
  def broadcast_streaming_chunk(stream_name, message_id, accumulated_text)
    html = ApplicationController.render(
      partial: "messages/streaming_content",
      locals: { content: accumulated_text, message_id: message_id }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "message_content_#{message_id}",
      html: html
    )
  end

  # Broadcast a tool/status indicator during tool rounds
  def broadcast_streaming_status(stream_name, message_id, status_text)
    html = ApplicationController.render(
      partial: "messages/streaming_status",
      locals: { status_text: status_text, message_id: message_id }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "message_content_#{message_id}",
      html: html
    )
  end

  # Broadcast the final fully-rendered message (with markdown) replacing the
  # streaming placeholder. Uses the full message partial (outer wrapper + bubble)
  # since it replaces the entire message div.
  def broadcast_final_message(stream_name, message_id, message)
    html = ApplicationController.render(
      partial: "messages/message",
      locals: { message: message }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "message_#{message_id}",
      html: html
    )
  end
end
