User.find_or_create_by!(email: "demo@loadstone.dev") do |u|
  u.name = "Demo User"
  u.jira_account_id = ENV.fetch("JIRA_USER_ACCOUNT_ID", "your-jira-account-id")
  u.github_username = ENV.fetch("GITHUB_USERNAME", "test-user")
end
