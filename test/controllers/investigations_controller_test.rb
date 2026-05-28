require "test_helper"
require "minitest/mock"

class InvestigationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Override so ActiveJob::TestHelper swaps in the test adapter even though
  # the app-wide adapter is :solid_queue.
  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end

  test "create enqueues job and creates queued investigation" do
    idea = ideas(:filters_table)
    assert_enqueued_with(job: RunInvestigationJob) do
      assert_difference "Investigation.count", 1 do
        post idea_investigations_path(idea), params: { investigation: { prompt: "steering" } }
      end
    end
    inv = Investigation.last
    assert_equal "queued", inv.status
    assert_equal "steering", inv.prompt
    assert_redirected_to idea_path(idea)
  end

  test "create without steering works" do
    idea = ideas(:filters_table)
    assert_difference "Investigation.count", 1 do
      post idea_investigations_path(idea), params: { investigation: { prompt: "" } }
    end
    assert_nil Investigation.last.prompt.presence
  end

  test "show renders investigation with idea context" do
    idea = ideas(:filters_table)
    inv = idea.investigations.create!(status: "queued")
    get idea_investigation_path(idea, inv)
    assert_response :success
  end

  test "distil succeeds for done investigation" do
    inv = investigations(:done_one_with_report)
    fake = Object.new.tap do |o|
      o.define_singleton_method(:chat) { |messages:, tools: nil| { content: "## Findings — 8 May\n\nstubbed body." } }
    end

    AgentService.stub :new, ->(*) { fake } do
      post distil_idea_investigation_path(inv.idea, inv)
    end

    inv.reload
    assert_not_nil inv.distilled_at
    assert_match(/stubbed body/, inv.idea.reload.body)
  end

  test "distil refuses non-done investigation" do
    inv = investigations(:pending)
    post distil_idea_investigation_path(inv.idea, inv)
    assert_redirected_to idea_path(inv.idea)
    assert_match(/completed/, flash[:alert])
  end

  test "distil reports agent failure as flash" do
    inv = investigations(:done_one_with_report)
    raising = Object.new.tap do |o|
      o.define_singleton_method(:chat) { |messages:, tools: nil| raise StandardError, "kaboom" }
    end

    AgentService.stub :new, ->(*) { raising } do
      post distil_idea_investigation_path(inv.idea, inv)
    end

    assert_redirected_to idea_path(inv.idea)
    assert_match(/kaboom/, flash[:alert])
    assert_nil inv.reload.distilled_at
  end

  test "create persists known mode" do
    idea = ideas(:filters_table)
    assert_difference "Investigation.count", 1 do
      post idea_investigations_path(idea), params: { investigation: { prompt: "p", mode: "spec" } }
    end
    assert_equal "spec", Investigation.last.mode
  end

  test "create with no mode persists nil" do
    idea = ideas(:filters_table)
    post idea_investigations_path(idea), params: { investigation: { prompt: "p" } }
    assert_nil Investigation.last.mode
  end

  test "create with unknown mode normalises to nil" do
    idea = ideas(:filters_table)
    post idea_investigations_path(idea), params: { investigation: { prompt: "p", mode: "bogus" } }
    assert_nil Investigation.last.mode
  end
end
