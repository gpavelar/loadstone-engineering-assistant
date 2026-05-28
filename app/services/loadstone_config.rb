module LoadstoneConfig
  module_function

  # Loads config/loadstone/<name>.yml, falling back to <name>.example.yml
  # when the real file doesn't exist. This lets a fresh checkout boot
  # cleanly — the user copies templates to the real names when ready.
  def load(name)
    real = Rails.root.join("config/loadstone/#{name}.yml")
    example = Rails.root.join("config/loadstone/#{name}.example.yml")
    path = real.exist? ? real : example
    return {} unless path.exist?
    YAML.load_file(path)
  end
end
