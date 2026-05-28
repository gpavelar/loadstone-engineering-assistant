require "anthropic"

ANTHROPIC_CLIENT = Anthropic::Client.new(
  api_key: ENV.fetch("ANTHROPIC_API_KEY", "dummy-key-for-test")
)
