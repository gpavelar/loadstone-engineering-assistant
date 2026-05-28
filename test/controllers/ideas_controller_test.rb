require "test_helper"

class IdeasControllerTest < ActionDispatch::IntegrationTest
  test "index renders list" do
    get ideas_path
    assert_response :success
    assert_select "h1", /Ideas/i
  end

  test "show renders idea" do
    idea = ideas(:filters_table)
    get idea_path(idea)
    assert_response :success
    assert_select "[data-idea-id='#{idea.id}']"
  end

  test "create makes a new idea with given title" do
    assert_difference "Idea.count", 1 do
      post ideas_path, params: { idea: { title: "New thought" } }
    end
    assert_redirected_to idea_path(Idea.last)
    assert_equal "New thought", Idea.last.title
  end

  test "create with empty title re-renders index" do
    assert_no_difference "Idea.count" do
      post ideas_path, params: { idea: { title: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update modifies title and body" do
    idea = ideas(:filters_table)
    patch idea_path(idea), params: { idea: { title: "Updated", body: "new body" } }
    assert_response :redirect
    idea.reload
    assert_equal "Updated", idea.title
    assert_equal "new body", idea.body
  end

  test "update via turbo stream returns turbo response" do
    idea = ideas(:filters_table)
    patch idea_path(idea),
          params: { idea: { title: "Updated" } },
          as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "archive sets archived_at" do
    idea = ideas(:filters_table)
    patch archive_idea_path(idea)
    assert_redirected_to ideas_path
    assert_not_nil idea.reload.archived_at
  end

  test "unarchive clears archived_at" do
    idea = ideas(:archived_one)
    patch unarchive_idea_path(idea)
    assert_redirected_to idea_path(idea)
    assert_nil idea.reload.archived_at
  end

  test "destroy removes idea" do
    idea = ideas(:filters_table)
    assert_difference "Idea.count", -1 do
      delete idea_path(idea)
    end
    assert_redirected_to ideas_path
  end
end
