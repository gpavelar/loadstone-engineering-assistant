module Tools
  class ConfluenceTool < BaseTool
    def call(input)
      if input["page_id"]
        fetch_page(input["page_id"])
      else
        search_pages(input)
      end
    end

    private

    def fetch_page(page_id)
      response = connection.get("/wiki/rest/api/content/#{page_id}") do |req|
        req.params["expand"] = "body.storage,version"
      end

      parsed = JSON.parse(response.body)
      raise "API error: #{parsed['message']}" if parsed["statusCode"] && parsed["statusCode"] != 200

      {
        page_id: page_id,
        title: parsed["title"],
        body: parsed.dig("body", "storage", "value"),
        version: parsed.dig("version", "number")
      }
    rescue => e
      { error: "Confluence fetch failed: #{e.message}" }
    end

    def search_pages(input)
      query = input["query"]
      space = input["space"]
      limit = input["limit"] || 10

      cql = "type=page AND text ~ \"#{query}\""
      cql += " AND space = \"#{space}\"" if space

      response = connection.get("/wiki/rest/api/content/search") do |req|
        req.params["cql"] = cql
        req.params["limit"] = limit
        req.params["expand"] = "body.view,space"
      end

      data = JSON.parse(response.body)
      pages = (data["results"] || []).map do |p|
        {
          title: p["title"],
          url: "https://#{ENV.fetch('JIRA_HOST', 'your-org.atlassian.net')}/wiki#{p['_links']['webui']}",
          space: p.dig("space", "name"),
          excerpt: p.dig("body", "view", "value")&.gsub(/<[^>]+>/, "")&.truncate(300)
        }
      end
      { pages: pages, total: data["totalSize"] }
    rescue => e
      { error: "Confluence search failed: #{e.message}" }
    end

    def connection
      @connection ||= Faraday.new(
        url: "https://#{ENV.fetch('JIRA_HOST', 'your-org.atlassian.net')}",
        headers: {
          "Authorization" => "Basic #{auth_token}",
          "Accept" => "application/json"
        }
      )
    end

    def auth_token
      require "base64"
      Base64.strict_encode64("#{ENV.fetch('JIRA_API_EMAIL', '')}:#{ENV.fetch('JIRA_API_TOKEN', '')}")
    end
  end
end
