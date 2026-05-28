class AgentService
  MAX_TOOL_ROUNDS = 10

  MODEL_MAP = {
    sonnet: "claude-sonnet-4-20250514",
    haiku: "claude-haiku-4-5-20251001"
  }.freeze

  def initialize(system_prompt:, model: :sonnet)
    @system_prompt = system_prompt
    @model = MODEL_MAP.fetch(model, MODEL_MAP[:sonnet])
    @client = ANTHROPIC_CLIENT
  end

  def chat(messages:, tools: nil)
    conversation = build_messages(messages)
    tools = tools.nil? ? tool_definitions : tools
    all_tool_calls = []

    round = 0
    start_time = Time.now
    log_agent "START model=#{@model} rounds_max=#{MAX_TOOL_ROUNDS}"

    loop do
      round += 1
      break if round > MAX_TOOL_ROUNDS

      round_start = Time.now
      log_agent "ROUND #{round} — calling Claude API..."

      response = @client.messages.create(
        model: @model,
        max_tokens: 4096,
        system_: @system_prompt,
        messages: conversation,
        tools: tools
      )

      api_ms = ((Time.now - round_start) * 1000).to_i
      text_parts = []
      tool_uses = []

      response.content.each do |block|
        case block.type
        when :text
          text_parts << block.text
        when :tool_use
          tool_uses << block
        end
      end

      if tool_uses.empty?
        total_ms = ((Time.now - start_time) * 1000).to_i
        log_agent "DONE rounds=#{round} total=#{total_ms}ms response=#{text_parts.join.length}chars"
        return { content: text_parts.join("\n"), tool_calls: all_tool_calls }
      end

      log_agent "ROUND #{round} — API responded in #{api_ms}ms — #{tool_uses.length} tool(s) requested: #{tool_uses.map(&:name).join(', ')}"

      # Build assistant content as serializable hashes for the conversation
      assistant_content = response.content.map do |block|
        case block.type
        when :text
          { type: "text", text: block.text }
        when :tool_use
          { type: "tool_use", id: block.id, name: block.name, input: block.input }
        end
      end.compact

      conversation << { role: "assistant", content: assistant_content }

      tool_results = tool_uses.map do |tool_use|
        tool_start = Time.now
        all_tool_calls << { name: tool_use.name, input: tool_use.input }
        result = execute_tool(tool_use.name, tool_use.input)
        tool_ms = ((Time.now - tool_start) * 1000).to_i
        log_agent "  TOOL #{tool_use.name} — #{tool_ms}ms — #{result.to_json.length}bytes"
        { type: "tool_result", tool_use_id: tool_use.id, content: result.to_json }
      end

      conversation << { role: "user", content: tool_results }
    end

    { content: "I wasn't able to complete your request after #{MAX_TOOL_ROUNDS} rounds.", tool_calls: all_tool_calls }
  end

  # Streaming version of chat. Tool rounds use non-streaming API (they're fast —
  # small responses with tool call decisions). The final text-only response uses
  # streaming so text chunks are yielded to the caller in real time.
  #
  # Yields [String chunk, String accumulated_text] for each text delta.
  # Also accepts on_tool_start: a callable that receives the tool name when a
  # tool round begins (for progress indicators).
  # Returns the same hash shape as #chat when complete.
  def chat_streaming(messages:, on_tool_start: nil, tools: nil, &block)
    raise ArgumentError, "chat_streaming requires a block" unless block_given?

    conversation = build_messages(messages)
    tools = tools.nil? ? tool_definitions : tools
    all_tool_calls = []
    start_time = Time.now

    round = 0
    log_agent "STREAM START model=#{@model}"
    loop do
      round += 1
      break if round > MAX_TOOL_ROUNDS

      # Non-streaming probe to check for tool calls
      response = @client.messages.create(
        model: @model,
        max_tokens: 4096,
        system_: @system_prompt,
        messages: conversation,
        tools: tools
      )

      tool_uses = response.content.select { |blk| blk.type == :tool_use }

      if tool_uses.any?
        # Tool round — process synchronously, notify caller of tool usage
        tool_uses.each { |tu| on_tool_start&.call(tu.name) }

        assistant_content = response.content.map do |blk|
          case blk.type
          when :text
            { type: "text", text: blk.text }
          when :tool_use
            { type: "tool_use", id: blk.id, name: blk.name, input: blk.input }
          end
        end.compact

        conversation << { role: "assistant", content: assistant_content }

        tool_results = tool_uses.map do |tool_use|
          all_tool_calls << { name: tool_use.name, input: tool_use.input }
          result = execute_tool(tool_use.name, tool_use.input)
          { type: "tool_result", tool_use_id: tool_use.id, content: result.to_json }
        end

        conversation << { role: "user", content: tool_results }
        next
      end

      # Final text-only round — we already have the non-streaming response with the
      # full text. Try streaming for real-time output, but fall back to the non-streaming
      # result if streaming fails for any reason.
      non_streaming_text = response.content
        .select { |blk| blk.type == :text }
        .map(&:text)
        .join("\n")

      accumulated = ""
      begin
        log_agent "ROUND #{round} — streaming final response..."
        stream = @client.messages.stream(
          model: @model,
          max_tokens: 4096,
          system_: @system_prompt,
          messages: conversation,
          tools: tools
        )

        stream.each do |event|
          if event.type == :text
            accumulated = event.snapshot
            yield event.text, accumulated
          end
        end
      rescue => e
        log_agent "STREAM FAILED: #{e.class}: #{e.message} — using non-streaming fallback"
        accumulated = ""
      end

      # Fall back to non-streaming text if streaming produced nothing or failed
      if accumulated.blank?
        accumulated = non_streaming_text
        log_agent "Using non-streaming fallback (#{accumulated.length} chars)"
      end

      total_ms = ((Time.now - start_time) * 1000).to_i
      log_agent "DONE rounds=#{round} total=#{total_ms}ms response=#{accumulated.length}chars"
      return { content: accumulated, tool_calls: all_tool_calls }
    end

    { content: "I wasn't able to complete your request after #{MAX_TOOL_ROUNDS} rounds.", tool_calls: all_tool_calls }
  end

  private

  def log_agent(msg)
    Rails.logger.info "[Loadstone::Agent] #{msg}"
  end

  def build_messages(messages)
    messages.map { |msg| { role: msg[:role], content: msg[:content] } }
  end

  def execute_tool(name, input)
    tool_class = tool_registry[name]
    return { error: "Unknown tool: #{name}" } unless tool_class

    # Ensure input is a plain Hash with string keys (Anthropic gem may return structured objects)
    plain_input = input.is_a?(Hash) ? input.transform_keys(&:to_s) : JSON.parse(input.to_json)

    Rails.logger.info "[Loadstone] Tool: #{name} | Input: #{plain_input.inspect}"
    result = tool_class.new.call(plain_input)
    Rails.logger.info "[Loadstone] Tool: #{name} | Result keys: #{result.keys rescue 'N/A'} | Size: #{result.to_json.length}"
    result
  rescue => e
    Rails.logger.error "[Loadstone] Tool: #{name} FAILED: #{e.class}: #{e.message}"
    { error: "Tool #{name} failed: #{e.message}" }
  end

  def tool_registry
    {
      "jira_search" => Tools::JiraTool,
      "jira_issue" => Tools::JiraTool,
      "jira_board_issues" => Tools::JiraTool,
      "slack_channel" => Tools::SlackTool,
      "slack_thread" => Tools::SlackTool,
      "github_prs" => Tools::GithubTool,
      "buildkite_builds" => Tools::BuildkiteTool,
      "lookup_persona" => Tools::PersonaTool,
      "search_expertise" => Tools::PersonaTool,
      "get_okrs" => Tools::OkrTool,
      "get_team_config" => Tools::PersonaTool,
      "confluence_search" => Tools::ConfluenceTool,
      "confluence_page" => Tools::ConfluenceTool
    }
  end

  def tool_definitions
    [
      {
        name: "jira_search",
        description: "Search Jira issues using JQL. Use this to find tickets assigned to a user, in a specific status, or matching criteria.",
        input_schema: { type: "object", properties: { jql: { type: "string", description: "JQL query string" }, max_results: { type: "integer", description: "Max results (default 20)" } }, required: ["jql"] }
      },
      {
        name: "jira_board_issues",
        description: "Fetch issues from the your team's Kanban board. This is the PRIMARY way to get team tickets — it respects the board's filter and shows only tickets that appear on the team's board. Use status_filter to filter by column (e.g. 'To Do', 'In Progress', 'In Review').",
        input_schema: { type: "object", properties: { board_issues: { type: "boolean", description: "Must be true", default: true }, status_filter: { type: "string", description: "Comma-separated statuses to filter, e.g. '\"In Progress\", \"In Review\"'. Leave empty for all." }, max_results: { type: "integer", description: "Max results (default 30)" }, include_description: { type: "boolean", description: "Include ticket descriptions (truncated to 500 chars). Use for duplicate detection. Default false." } }, required: ["board_issues"] }
      },
      {
        name: "jira_issue",
        description: "Get details for a specific Jira issue by key (e.g. PROJ-1218).",
        input_schema: { type: "object", properties: { issue_key: { type: "string", description: "Jira issue key like PROJ-1218" } }, required: ["issue_key"] }
      },
      {
        name: "slack_channel",
        description: "Read recent messages from a Slack channel. Returns the latest messages. Use channel name with # (e.g. '#engineering').",
        input_schema: { type: "object", properties: { channel: { type: "string", description: "Channel name (e.g. '#engineering')" }, limit: { type: "integer", description: "Number of messages (default 20)" } }, required: ["channel"] }
      },
      {
        name: "slack_thread",
        description: "Read replies in a Slack thread. Requires channel and thread timestamp.",
        input_schema: { type: "object", properties: { channel: { type: "string", description: "Channel name or ID" }, thread_ts: { type: "string", description: "Thread timestamp from a parent message" } }, required: ["channel", "thread_ts"] }
      },
      {
        name: "github_prs",
        description: "List pull requests for a GitHub user. Can filter by state and date range.",
        input_schema: { type: "object", properties: { username: { type: "string", description: "GitHub username" }, state: { type: "string", description: "PR state: open, closed, or all" }, since: { type: "string", description: "ISO date to filter PRs created after" } }, required: ["username"] }
      },
      {
        name: "buildkite_builds",
        description: "List recent Buildkite builds. Can filter by pipeline and branch.",
        input_schema: { type: "object", properties: { pipeline: { type: "string", description: "Pipeline slug" }, branch: { type: "string", description: "Branch name" }, count: { type: "integer", description: "Number of builds to return" } }, required: [] }
      },
      {
        name: "lookup_persona",
        description: "Look up a team member by name or role. Returns their skills, team, and contact info.",
        input_schema: { type: "object", properties: { query: { type: "string", description: "Name, role, or team to search for" } }, required: ["query"] }
      },
      {
        name: "search_expertise",
        description: "Find team members with specific skills or expertise.",
        input_schema: { type: "object", properties: { skill: { type: "string", description: "Skill or expertise to search for" } }, required: ["skill"] }
      },
      {
        name: "get_okrs",
        description: "Get OKR objectives and key results. Can filter by theme or search by ticket key.",
        input_schema: { type: "object", properties: { ticket_key: { type: "string", description: "Jira ticket key to find related OKR" }, theme: { type: "string", description: "OKR theme to filter by" } }, required: [] }
      },
      {
        name: "get_team_config",
        description: "Get team configuration including members, Slack channels, and escalation paths.",
        input_schema: { type: "object", properties: { team: { type: "string", description: "Team name" } }, required: [] }
      },
      {
        name: "confluence_search",
        description: "Search Confluence pages for documentation, RFCs, and team knowledge. Use to find context about systems, processes, and decisions.",
        input_schema: { type: "object", properties: { query: { type: "string", description: "Search text" }, space: { type: "string", description: "Confluence space key (optional)" }, limit: { type: "integer", description: "Max results (default 10)" } }, required: ["query"] }
      },
      {
        name: "confluence_page",
        description: "Fetch a single Confluence page by its numeric page ID. Returns title and body in storage format. Use for known planning pages, RFCs, or runbooks — NOT for keyword search (use confluence_search for that).",
        input_schema: {
          type: "object",
          properties: {
            page_id: { type: "string", description: "Numeric page ID, e.g. '123456'" }
          },
          required: ["page_id"]
        }
      }
    ]
  end
end
