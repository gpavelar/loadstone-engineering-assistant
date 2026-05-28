require "test_helper"

class Tools::PersonaToolTest < ActiveSupport::TestCase
  setup do
    @tool = Tools::PersonaTool.new
  end

  test "lookup finds by name" do
    result = @tool.call({ "action" => "lookup", "query" => "Alex Rivera" })
    assert result[:personas].any? { |p| p[:name] == "Alex Rivera" }
  end

  test "search_expertise finds by skill" do
    result = @tool.call({ "action" => "search_expertise", "skill" => "indexing" })
    assert result[:matches].any? { |m| m[:name] == "Alex Rivera" }
  end

  test "get_team_config returns team info" do
    result = @tool.call({ "action" => "get_team_config", "team" => "Your Team" })
    assert_equal "Your Team", result[:team][:name]
  end
end
