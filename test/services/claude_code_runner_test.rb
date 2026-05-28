require "test_helper"
require "minitest/mock"

class ClaudeCodeRunnerTest < ActiveSupport::TestCase
  test "returns parsed result on success" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, [
      { "result" => "Hello report" }.to_json,
      "",
      mock_status(0)
    ] do
      result = runner.run(prompt: "test", system_prompt: "sys")
      assert_equal "Hello report", result[:text]
      assert_nil result[:error]
    end
  end

  test "returns error on non-zero exit" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, [ "", "auth required", mock_status(1) ] do
      result = runner.run(prompt: "test", system_prompt: "sys")
      assert_nil result[:text]
      assert_match(/auth required/, result[:error])
    end
  end

  test "returns error on invalid JSON" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, [ "not json", "", mock_status(0) ] do
      result = runner.run(prompt: "test", system_prompt: "sys")
      assert_nil result[:text]
      assert_match(/non-JSON/, result[:error])
    end
  end

  test "returns error on missing result key" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, [ { other: "x" }.to_json, "", mock_status(0) ] do
      result = runner.run(prompt: "test", system_prompt: "sys")
      assert_match(/missing result/, result[:error])
    end
  end

  test "returns error when CLI is not runnable" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, ->(*) { raise Errno::ENOENT, "claude" } do
      result = runner.run(prompt: "x", system_prompt: "s")
      assert_nil result[:text]
      assert_match(/not runnable/, result[:error])
    end
  end

  test "returns error on timeout" do
    runner = ClaudeCodeRunner.new
    runner.stub :spawn_claude, ->(*) { raise Timeout::Error } do
      result = runner.run(prompt: "x", system_prompt: "s")
      assert_nil result[:text]
      assert_match(/timeout/, result[:error])
    end
  end

  private

  def mock_status(code)
    Struct.new(:exitstatus, :success?).new(code, code == 0)
  end
end
