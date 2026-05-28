require "test_helper"

class IdeaTest < ActiveSupport::TestCase
  test "requires title" do
    idea = Idea.new(user: users(:alice), title: nil)
    assert_not idea.valid?
    assert_includes idea.errors[:title], "can't be blank"
  end

  test "defaults body to empty string" do
    idea = Idea.create!(user: users(:alice), title: "Test")
    assert_equal "", idea.body
  end

  test "active scope excludes archived" do
    active = Idea.create!(user: users(:alice), title: "Active")
    archived = Idea.create!(user: users(:alice), title: "Old", archived_at: Time.current)

    assert_includes Idea.active, active
    assert_not_includes Idea.active, archived
  end

  test "archive! sets archived_at" do
    idea = Idea.create!(user: users(:alice), title: "Test")
    assert_nil idea.archived_at
    idea.archive!
    assert_not_nil idea.archived_at
  end

  test "unarchive! clears archived_at" do
    idea = Idea.create!(user: users(:alice), title: "Test", archived_at: Time.current)
    idea.unarchive!
    assert_nil idea.archived_at
  end

  test "destroy cascades to investigations" do
    idea = Idea.create!(user: users(:alice), title: "Test")
    idea.investigations.create!(status: "queued")
    assert_difference "Investigation.count", -1 do
      idea.destroy!
    end
  end

  test "archived? reflects archive state" do
    idea = Idea.create!(user: users(:alice), title: "Test")
    assert_not idea.archived?
    idea.archive!
    assert idea.archived?
    idea.unarchive!
    assert_not idea.archived?
  end

  test "archived scope includes only archived" do
    active = Idea.create!(user: users(:alice), title: "Active")
    archived = Idea.create!(user: users(:alice), title: "Old", archived_at: Time.current)

    assert_includes Idea.archived, archived
    assert_not_includes Idea.archived, active
  end

  test "user has many ideas" do
    user = users(:alice)
    assert_respond_to user, :ideas
  end

  test "deleting user destroys ideas" do
    user = users(:alice)
    user.ideas.create!(title: "Goes away")
    assert_difference "Idea.count", -user.ideas.count do
      user.destroy!
    end
  end

  test "append_to_body! adds text after two newlines" do
    idea = Idea.create!(user: users(:alice), title: "T", body: "existing body")
    idea.append_to_body!("new section")
    assert_equal "existing body\n\nnew section", idea.reload.body
  end

  test "append_to_body! handles empty body without leading newlines" do
    idea = Idea.create!(user: users(:alice), title: "T")
    idea.append_to_body!("first section")
    assert_equal "first section", idea.reload.body
  end

  test "append_to_body! strips trailing whitespace" do
    idea = Idea.create!(user: users(:alice), title: "T", body: "existing\n\n")
    idea.append_to_body!("new")
    assert_equal "existing\n\nnew", idea.reload.body
  end
end
