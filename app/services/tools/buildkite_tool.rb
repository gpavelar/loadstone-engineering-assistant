module Tools
  class BuildkiteTool < BaseTool
    def call(input)
      org = ENV.fetch("BUILDKITE_ORG_SLUG", "your-org")
      pipeline = input["pipeline"]
      count = input["count"] || 10

      path = pipeline ? "/v2/organizations/#{org}/pipelines/#{pipeline}/builds" : "/v2/organizations/#{org}/builds"

      response = connection.get(path) do |req|
        req.params["per_page"] = count
        req.params["branch"] = input["branch"] if input["branch"]
      end

      builds = JSON.parse(response.body).map do |b|
        {
          number: b["number"],
          state: b["state"],
          branch: b["branch"],
          message: b["message"]&.truncate(100),
          pipeline: b.dig("pipeline", "slug"),
          created_at: b["created_at"],
          url: b["web_url"]
        }
      end
      { builds: builds }
    rescue => e
      { error: "Buildkite fetch failed: #{e.message}" }
    end

    private

    def connection
      @connection ||= Faraday.new(
        url: "https://api.buildkite.com",
        headers: { "Authorization" => "Bearer #{ENV.fetch('BUILDKITE_API_TOKEN', '')}" }
      )
    end
  end
end
