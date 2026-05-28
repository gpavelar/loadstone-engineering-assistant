require "test_helper"

class Tools::OkrToolTest < ActiveSupport::TestCase
  setup do
    @tool = Tools::OkrTool.new
  end

  test "finds OKR by ticket key" do
    result = @tool.call({ "ticket_key" => "PROJ-1218" })
    assert result[:okrs].any? { |o| o[:id] == "okr-ftb-search" }
  end

  test "filters OKR by theme" do
    result = @tool.call({ "theme" => "Fix-the-basics" })
    assert result[:okrs].all? { |o| o[:theme] == "Fix-the-basics" }
  end

  test "returns all OKRs when no filter" do
    result = @tool.call({})
    assert result[:okrs].length >= 3
  end
end
