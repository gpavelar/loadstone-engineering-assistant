require "test_helper"

class SkillRouterTest < ActiveSupport::TestCase
  test "routes /compass to compass skill" do
    result = SkillRouter.route("/compass")
    assert_equal :compass, result[:skill]
    assert_equal Skills::Compass.system_prompt, result[:system_prompt]
    assert_equal "", result[:user_input]
  end

  test "routes /compass with extra text" do
    result = SkillRouter.route("/compass what should I focus on?")
    assert_equal :compass, result[:skill]
    assert_equal "what should I focus on?", result[:user_input]
  end

  test "routes /journal to journal skill" do
    result = SkillRouter.route("/journal")
    assert_equal :journal, result[:skill]
    assert_equal Skills::Journal.system_prompt, result[:system_prompt]
    assert_equal "", result[:user_input]
  end

  test "routes /blockers to blockers skill" do
    result = SkillRouter.route("/blockers")
    assert_equal :blockers, result[:skill]
    assert_equal Skills::Blockers.system_prompt, result[:system_prompt]
  end

  test "routes /stakeholders to stakeholders skill" do
    result = SkillRouter.route("/stakeholders")
    assert_equal :stakeholders, result[:skill]
    assert_equal Skills::Stakeholders.system_prompt, result[:system_prompt]
  end

  test "routes /checkin to checkin skill" do
    result = SkillRouter.route("/checkin")
    assert_equal :checkin, result[:skill]
    assert_equal Skills::Checkin.system_prompt, result[:system_prompt]
    assert_equal "", result[:user_input]
  end

  test "routes plain text to general skill" do
    result = SkillRouter.route("What are my open PRs?")
    assert_equal :general, result[:skill]
    assert_equal Skills::General.system_prompt, result[:system_prompt]
    assert_equal "What are my open PRs?", result[:user_input]
  end

  test "routes are case-insensitive for command" do
    result = SkillRouter.route("/COMPASS")
    assert_equal :compass, result[:skill]
  end

  test "handles leading whitespace in input" do
    result = SkillRouter.route("  /journal  ")
    assert_equal :journal, result[:skill]
  end

  test "routes /planning-gap to planning_gap skill" do
    result = SkillRouter.route("/planning-gap search")
    assert_equal :planning_gap, result[:skill]
    assert_equal Skills::PlanningGap.system_prompt, result[:system_prompt]
    assert_equal "search", result[:user_input]
  end

  test "sonnet skills return model :sonnet" do
    %w[/compass /journal /blockers /retro /prep /checkin /planning-gap].each do |cmd|
      result = SkillRouter.route(cmd)
      assert_equal :sonnet, result[:model], "Expected #{cmd} to use :sonnet"
    end
  end

  test "haiku skills return model :haiku" do
    %w[/stakeholders /board-hygiene].each do |cmd|
      result = SkillRouter.route(cmd)
      assert_equal :haiku, result[:model], "Expected #{cmd} to use :haiku"
    end
  end

  test "general natural language questions return model :haiku" do
    result = SkillRouter.route("What are my open PRs?")
    assert_equal :haiku, result[:model]
  end
end
