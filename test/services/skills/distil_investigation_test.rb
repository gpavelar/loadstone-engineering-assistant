require "test_helper"
require "minitest/mock"

class Skills::DistilInvestigationTest < ActiveSupport::TestCase
  def fake_agent(content:)
    Object.new.tap do |o|
      o.define_singleton_method(:chat) { |messages:, tools: nil| { content: content } }
    end
  end

  def raising_agent(error_class:, message:)
    Object.new.tap do |o|
      o.define_singleton_method(:chat) { |messages:, tools: nil| raise error_class, message }
    end
  end

  test "happy path returns section with link" do
    inv = investigations(:done_one_with_report)
    AgentService.stub :new, ->(*) { fake_agent(content: "## Findings — 8 May\n\nTest finding.") } do
      result = Skills::DistilInvestigation.new(inv).call

      assert result.success?, "expected success but got error: #{result.error}"
      assert_match(/## Findings/, result.section)
      assert_match(/\[Full investigation →\]/, result.section)
    end
  end

  test "returns failure when investigation has no report" do
    inv = investigations(:pending) # status: queued, no conversation
    result = Skills::DistilInvestigation.new(inv).call

    assert_not result.success?
    assert_match(/no report/, result.error)
  end

  test "returns failure when agent raises" do
    inv = investigations(:done_one_with_report)
    AgentService.stub :new, ->(*) { raising_agent(error_class: StandardError, message: "boom") } do
      result = Skills::DistilInvestigation.new(inv).call

      assert_not result.success?
      assert_match(/boom/, result.error)
    end
  end

  test "returns failure when agent returns empty content" do
    inv = investigations(:done_one_with_report)
    AgentService.stub :new, ->(*) { fake_agent(content: "") } do
      result = Skills::DistilInvestigation.new(inv).call

      assert_not result.success?
      assert_match(/Empty/, result.error)
    end
  end
end
