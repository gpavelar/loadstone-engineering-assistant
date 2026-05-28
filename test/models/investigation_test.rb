require "test_helper"

class InvestigationTest < ActiveSupport::TestCase
  test "belongs to idea" do
    inv = investigations(:pending)
    assert_not_nil inv.idea
  end

  test "requires status" do
    inv = Investigation.new(idea: ideas(:filters_table), status: nil)
    assert_not inv.valid?
  end

  test "status inclusion" do
    inv = Investigation.new(idea: ideas(:filters_table), status: "bogus")
    assert_not inv.valid?
    assert_includes inv.errors[:status], "is not included in the list"
  end

  test "valid statuses" do
    Investigation::STATUSES.each do |s|
      inv = Investigation.new(idea: ideas(:filters_table), status: s)
      assert inv.valid?, "status #{s} should be valid"
    end
  end

  test "done? when status is done" do
    inv = Investigation.new(status: "done")
    assert inv.done?
    assert_not inv.running?
  end

  test "running? when status is running" do
    inv = Investigation.new(status: "running")
    assert inv.running?
  end

  test "queued? and failed? predicates" do
    assert Investigation.new(status: "queued").queued?
    assert Investigation.new(status: "failed").failed?
  end

  test "distilled_at can be nil or set" do
    inv = investigations(:pending)
    assert_nil inv.distilled_at

    inv.update!(distilled_at: Time.current)
    assert_not_nil inv.reload.distilled_at
  end

  test "mode can be nil or any string at the DB level" do
    inv = investigations(:pending)
    assert_nil inv.mode

    inv.update!(mode: "research")
    assert_equal "research", inv.reload.mode

    # DB has no constraint — validation is done in controller. Confirm the model accepts anything.
    inv.update!(mode: "bogus")
    assert_equal "bogus", inv.reload.mode
  end
end
