module Tools
  class JiraTool < BaseTool
    BASE_URL = "https://#{ENV.fetch('JIRA_HOST', 'your-org.atlassian.net')}"
    BOARD_ID = ENV.fetch("JIRA_BOARD_ID", "0")
    BOARD_CACHE = {}
    CACHE_TTL = 5 * 60 # 5 minutes

    def call(input)
      @include_description = input["include_description"] == true
      if input["issue_key"]
        fetch_issue(input["issue_key"])
      elsif input["board_issues"]
        board_issues(input["status_filter"], input["max_results"] || 30)
      else
        search(input["jql"], input["max_results"] || 20)
      end
    end

    private

    # Fetch issues from the team's board (respects the board's filter)
    def board_issues(status_filter, max_results)
      cache_key = "board_#{status_filter}_#{max_results}"
      cached = BOARD_CACHE[cache_key]
      if cached && (Time.now - cached[:at]) < CACHE_TTL
        return cached[:data]
      end

      jql = if status_filter
              "status IN (#{status_filter}) ORDER BY rank ASC"
            else
              "ORDER BY rank ASC"
            end

      response = connection.get("/rest/agile/1.0/board/#{BOARD_ID}/issue") do |req|
        req.params["jql"] = jql
        req.params["maxResults"] = max_results
        req.params["fields"] = issue_fields
      end
      data = JSON.parse(response.body)
      issues = (data["issues"] || []).map { |i| format_issue(i) }
      result = { issues: issues, total: data["total"] }

      BOARD_CACHE[cache_key] = { data: result, at: Time.now }
      result
    rescue => e
      { error: "Board issues fetch failed: #{e.message}" }
    end

    # Standard JQL search across the project
    def search(jql, max_results)
      response = connection.get("/rest/api/3/search/jql") do |req|
        req.params["jql"] = jql
        req.params["maxResults"] = max_results
        req.params["fields"] = issue_fields
      end
      data = JSON.parse(response.body)
      issues = (data["issues"] || []).map { |i| format_issue(i) }
      { issues: issues, total: data["total"] }
    rescue => e
      { error: "Jira search failed: #{e.message}" }
    end

    def fetch_issue(key)
      response = connection.get("/rest/api/3/issue/#{key}") do |req|
        req.params["fields"] = "summary,status,assignee,priority,issuetype,description,updated,created,labels"
      end
      data = JSON.parse(response.body)
      { issue: format_issue(data) }
    rescue => e
      { error: "Jira fetch failed: #{e.message}" }
    end

    def format_issue(issue)
      fields = issue["fields"] || {}
      parent = fields["parent"]
      links = (fields["issuelinks"] || []).map do |link|
        {
          type: link.dig("type", "name"),
          inward: link.dig("inwardIssue", "key"),
          outward: link.dig("outwardIssue", "key"),
          summary: link.dig("inwardIssue", "fields", "summary") || link.dig("outwardIssue", "fields", "summary")
        }
      end

      result = {
        key: issue["key"],
        summary: fields["summary"],
        status: fields.dig("status", "name"),
        status_category: fields.dig("status", "statusCategory", "name"),
        assignee: fields.dig("assignee", "displayName"),
        priority: fields.dig("priority", "name"),
        type: fields.dig("issuetype", "name"),
        hierarchy_level: fields.dig("issuetype", "hierarchyLevel"),
        parent_key: parent&.dig("key"),
        parent_summary: parent&.dig("fields", "summary"),
        parent_type: parent&.dig("fields", "issuetype", "name"),
        links: links.any? ? links : nil,
        updated: fields["updated"],
        created: fields["created"],
        labels: fields["labels"]
      }

      # Include description when requested (truncated to avoid token bloat)
      if @include_description && fields["description"]
        desc = fields["description"]
        # Handle ADF (Atlassian Document Format) — extract plain text
        desc_text = if desc.is_a?(Hash)
                      extract_adf_text(desc)
                    else
                      desc.to_s
                    end
        result[:description] = desc_text.truncate(500) if desc_text.present?
      end

      result.compact
    end

    def extract_adf_text(node)
      return "" unless node.is_a?(Hash)
      text = node["text"] || ""
      (node["content"] || []).each { |child| text += " " + extract_adf_text(child) }
      text.strip
    end

    def issue_fields
      base = "summary,status,assignee,priority,issuetype,updated,created,labels,parent,issuelinks"
      base += ",description" if @include_description
      base
    end

    def connection
      @connection ||= Faraday.new(
        url: BASE_URL,
        headers: {
          "Authorization" => "Basic #{jira_auth_token}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      )
    end

    def jira_auth_token
      require "base64"
      Base64.strict_encode64("#{ENV.fetch('JIRA_API_EMAIL', '')}:#{ENV.fetch('JIRA_API_TOKEN', '')}")
    end
  end
end
