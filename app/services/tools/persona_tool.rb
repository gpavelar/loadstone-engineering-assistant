module Tools
  class PersonaTool < BaseTool
    def call(input)
      action = input["action"] || infer_action(input)
      case action
      when "lookup" then lookup(input["query"])
      when "search_expertise" then search_expertise(input["skill"])
      when "get_team_config" then get_team_config(input["team"])
      else lookup(input["query"] || input["skill"] || "")
      end
    end

    private

    def infer_action(input)
      return "search_expertise" if input["skill"]
      return "get_team_config" if input["team"]
      "lookup"
    end

    def personas
      @personas ||= (LoadstoneConfig.load("personas")["personas"] || [])
    end

    def team_config
      @team_config ||= (LoadstoneConfig.load("team_config")["teams"] || {})
    end

    def lookup(query)
      query_down = query.to_s.downcase
      matches = personas.select do |p|
        p["name"].downcase.include?(query_down) ||
          p["role"].downcase.include?(query_down) ||
          p["team"].downcase.include?(query_down)
      end
      { personas: matches.map(&:symbolize_keys) }
    end

    def search_expertise(skill)
      skill_down = skill.to_s.downcase
      matches = personas.select do |p|
        p["skills"].any? { |s| s.downcase.include?(skill_down) }
      end.map do |p|
        matching_skills = p["skills"].select { |s| s.downcase.include?(skill_down) }
        p.symbolize_keys.merge(matching_skills: matching_skills)
      end
      { matches: matches }
    end

    def get_team_config(team_name)
      if team_name
        team_key = team_config.keys.find { |k| team_config[k]["name"].downcase.include?(team_name.to_s.downcase) }
        team = team_config[team_key] if team_key
      end
      team ||= team_config.values.first
      { team: team.symbolize_keys }
    end
  end
end
