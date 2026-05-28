module Tools
  class BaseTool
    def call(input)
      raise NotImplementedError, "Subclasses must implement #call"
    end
  end
end
