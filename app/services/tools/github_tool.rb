module Tools
  class GithubTool < BaseTool
    def call(input)
      username = input["username"]
      state = input["state"] || "all"
      since = input["since"]

      query = "author:#{username} is:pr"
      query += " is:#{state}" unless state == "all"
      query += " created:>=#{since}" if since

      response = connection.get("/search/issues") do |req|
        req.params["q"] = query
        req.params["sort"] = "updated"
        req.params["order"] = "desc"
        req.params["per_page"] = 20
      end

      data = JSON.parse(response.body)
      prs = (data["items"] || []).map do |pr|
        {
          number: pr["number"],
          title: pr["title"],
          state: pr["state"],
          url: pr["html_url"],
          repo: pr["repository_url"]&.split("/")&.last(2)&.join("/"),
          created_at: pr["created_at"],
          updated_at: pr["updated_at"]
        }
      end
      { pull_requests: prs, total: data["total_count"] }
    rescue => e
      { error: "GitHub search failed: #{e.message}" }
    end

    private

    def connection
      @connection ||= Faraday.new(
        url: "https://api.github.com",
        headers: {
          "Authorization" => "Bearer #{ENV.fetch('GITHUB_TOKEN', '')}",
          "Accept" => "application/vnd.github+json"
        }
      )
    end
  end
end
