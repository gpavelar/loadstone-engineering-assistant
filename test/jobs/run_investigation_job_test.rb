require "test_helper"
require "minitest/mock"

class RunInvestigationJobTest < ActiveJob::TestCase
  def setup
    @idea = ideas(:filters_table)
    @investigation = @idea.investigations.create!(status: "queued", prompt: "focus on perf")
  end

  test "happy path marks done and stores conversation" do
    stub_runner(text: "# Report\nfindings here") do
      RunInvestigationJob.perform_now(@investigation.id)
    end

    @investigation.reload
    assert_equal "done", @investigation.status
    assert_not_nil @investigation.conversation_id
    msg = @investigation.conversation.messages.last
    assert_equal "assistant", msg.role
    assert_match(/findings here/, msg.content)
  end

  test "failure stores error_message" do
    stub_runner(error: "auth required") do
      RunInvestigationJob.perform_now(@investigation.id)
    end

    @investigation.reload
    assert_equal "failed", @investigation.status
    assert_match(/auth required/, @investigation.error_message)
  end

  test "missing investigation exits cleanly" do
    assert_nothing_raised do
      RunInvestigationJob.perform_now(999_999)
    end
  end

  test "passes prompt including title, body, steering" do
    captured = nil
    fake_runner = Object.new
    fake_runner.define_singleton_method(:run) do |prompt:, system_prompt:|
      captured = prompt
      { text: "ok", error: nil, raw_stdout: "{}" }
    end
    ClaudeCodeRunner.stub :new, fake_runner do
      RunInvestigationJob.perform_now(@investigation.id)
    end

    assert_match(/IDEA:.+Filters/, captured)
    assert_match(/NOTES:/, captured)
    assert_match(/STEERING: focus on perf/, captured)
  end

  test "rescue path destroys orphaned conversation" do
    raised_runner = Object.new
    raised_runner.define_singleton_method(:run) do |prompt:, system_prompt:|
      raise StandardError, "kaboom"
    end

    initial_conversations = Conversation.count

    ClaudeCodeRunner.stub :new, raised_runner do
      RunInvestigationJob.perform_now(@investigation.id)
    end

    @investigation.reload
    assert_equal "failed", @investigation.status
    assert_match(/kaboom/, @investigation.error_message)
    # Conversation created mid-flight should have been destroyed by the rescue
    assert_equal initial_conversations, Conversation.count
  end

  test "system prompt includes mode suffix when mode set" do
    idea = ideas(:filters_table)
    inv = idea.investigations.create!(status: "queued", prompt: "p", mode: "spec")
    captured_system = nil

    fake_runner = Object.new.tap do |o|
      o.define_singleton_method(:run) do |prompt:, system_prompt:|
        captured_system = system_prompt
        { text: "ok", error: nil, raw_stdout: "{}" }
      end
    end

    ClaudeCodeRunner.stub :new, ->(*) { fake_runner } do
      RunInvestigationJob.perform_now(inv.id)
    end

    assert_match(/Mode: Spec/, captured_system)
    assert_match(/Technical RFC/, captured_system)
  end

  test "system prompt has no mode suffix when mode nil" do
    idea = ideas(:filters_table)
    inv = idea.investigations.create!(status: "queued", prompt: "p", mode: nil)
    captured_system = nil

    fake_runner = Object.new.tap do |o|
      o.define_singleton_method(:run) do |prompt:, system_prompt:|
        captured_system = system_prompt
        { text: "ok", error: nil, raw_stdout: "{}" }
      end
    end

    ClaudeCodeRunner.stub :new, ->(*) { fake_runner } do
      RunInvestigationJob.perform_now(inv.id)
    end

    assert_no_match(/## Mode:/, captured_system)
  end

  private

  def stub_runner(text: nil, error: nil)
    fake = Object.new
    result = { text: text, error: error, raw_stdout: "{}" }
    fake.define_singleton_method(:run) { |prompt:, system_prompt:| result }
    ClaudeCodeRunner.stub :new, fake do
      yield
    end
  end
end
