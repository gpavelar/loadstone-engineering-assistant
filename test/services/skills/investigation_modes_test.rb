require "test_helper"

class Skills::InvestigationModesTest < ActiveSupport::TestCase
  test "MODES defines four modes with required keys" do
    expected = %w[research plan compare spec]
    assert_equal expected.sort, Skills::InvestigationModes::MODES.keys.sort

    Skills::InvestigationModes::MODES.each do |key, meta|
      assert meta[:label].present?, "#{key} missing :label"
      assert meta[:steering].present?, "#{key} missing :steering"
      assert meta[:prompt_suffix].present?, "#{key} missing :prompt_suffix"
    end
  end

  test "suffix_for returns the suffix for a known mode" do
    suffix = Skills::InvestigationModes.suffix_for("research")
    assert_match(/Mode: Research/, suffix)
  end

  test "suffix_for returns empty string for nil" do
    assert_equal "", Skills::InvestigationModes.suffix_for(nil)
  end

  test "suffix_for returns empty string for blank" do
    assert_equal "", Skills::InvestigationModes.suffix_for("")
  end

  test "suffix_for returns empty string for unknown mode" do
    assert_equal "", Skills::InvestigationModes.suffix_for("bogus")
  end

  test "steering_for returns text for a known mode" do
    text = Skills::InvestigationModes.steering_for("plan")
    assert text.length > 10
  end

  test "steering_for returns empty string for nil / blank / unknown" do
    assert_equal "", Skills::InvestigationModes.steering_for(nil)
    assert_equal "", Skills::InvestigationModes.steering_for("")
    assert_equal "", Skills::InvestigationModes.steering_for("bogus")
  end

  test "label_for returns mode label, or 'Default' for nil" do
    assert_equal "Default", Skills::InvestigationModes.label_for(nil)
    assert_equal "Default", Skills::InvestigationModes.label_for("")
    assert_equal "Research", Skills::InvestigationModes.label_for("research")
    assert_equal "Default", Skills::InvestigationModes.label_for("bogus")
  end

  test "valid? returns true for nil and known modes, false for unknown" do
    assert Skills::InvestigationModes.valid?(nil)
    assert Skills::InvestigationModes.valid?("")
    assert Skills::InvestigationModes.valid?("research")
    assert_not Skills::InvestigationModes.valid?("bogus")
  end
end
