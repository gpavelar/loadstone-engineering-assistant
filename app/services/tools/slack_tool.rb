module Tools
  class SlackTool < BaseTool
    def call(input)
      unless ENV["SLACK_BOT_TOKEN"].present?
        return { message: "Slack not configured. Add SLACK_BOT_TOKEN to .env to enable Slack integration.", channels: [] }
      end

      if input["thread_ts"] && input["channel"]
        fetch_thread(input["channel"], input["thread_ts"])
      elsif input["channel"]
        fetch_channel(input["channel"], input["limit"] || 20)
      else
        { error: "Provide a channel name (e.g. '#engineering')" }
      end
    end

    private

    def fetch_channel(channel, limit)
      # Resolve channel name to ID if needed
      channel_id = channel.start_with?("C") ? channel : resolve_channel_id(channel)
      return { error: "Could not find channel: #{channel}" } unless channel_id

      response = connection.get("/api/conversations.history") do |req|
        req.params["channel"] = channel_id
        req.params["limit"] = limit
      end

      data = JSON.parse(response.body)
      unless data["ok"]
        return { error: "Slack API error: #{data['error']}" }
      end

      messages = (data["messages"] || []).map { |m| format_message(m) }
      { channel: channel, messages: messages }
    rescue => e
      { error: "Slack channel fetch failed: #{e.message}" }
    end

    def fetch_thread(channel, thread_ts)
      channel_id = channel.start_with?("C") ? channel : resolve_channel_id(channel)
      return { error: "Could not find channel: #{channel}" } unless channel_id

      response = connection.get("/api/conversations.replies") do |req|
        req.params["channel"] = channel_id
        req.params["ts"] = thread_ts
        req.params["limit"] = 50
      end

      data = JSON.parse(response.body)
      unless data["ok"]
        return { error: "Slack API error: #{data['error']}" }
      end

      messages = (data["messages"] || []).map { |m| format_message(m) }
      { channel: channel, thread_ts: thread_ts, messages: messages }
    rescue => e
      { error: "Slack thread fetch failed: #{e.message}" }
    end

    def resolve_channel_id(name)
      clean_name = name.gsub(/^#/, "")

      response = connection.get("/api/conversations.list") do |req|
        req.params["types"] = "public_channel,private_channel"
        req.params["limit"] = 200
      end

      data = JSON.parse(response.body)
      return nil unless data["ok"]

      channel = (data["channels"] || []).find { |c| c["name"] == clean_name }
      channel&.dig("id")
    rescue
      nil
    end

    def format_message(msg)
      {
        user: msg["user"],
        text: msg["text"]&.truncate(500),
        ts: msg["ts"],
        thread_ts: msg["thread_ts"],
        reply_count: msg["reply_count"],
        time: msg["ts"] ? Time.at(msg["ts"].to_f).utc.iso8601 : nil
      }
    end

    def connection
      @connection ||= Faraday.new(
        url: "https://slack.com",
        headers: {
          "Authorization" => "Bearer #{ENV.fetch('SLACK_BOT_TOKEN', '')}",
          "Content-Type" => "application/json"
        }
      )
    end
  end
end
