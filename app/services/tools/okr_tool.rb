module Tools
  class OkrTool < BaseTool
    def call(input)
      results = okrs
      if input["ticket_key"]
        results = results.select { |o| o["related_tickets"]&.include?(input["ticket_key"]) }
      end
      if input["theme"]
        results = results.select { |o| o["theme"].downcase.include?(input["theme"].downcase) }
      end
      { okrs: results.map(&:symbolize_keys) }
    end

    private

    def okrs
      @okrs ||= (LoadstoneConfig.load("okrs")["okrs"] || [])
    end
  end
end
