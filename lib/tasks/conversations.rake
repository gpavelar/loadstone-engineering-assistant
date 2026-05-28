namespace :loadstone do
  desc "Show recent conversations with messages and tool calls"
  task inspect: :environment do
    limit = ENV.fetch("LIMIT", 3).to_i
    convos = Conversation.includes(:messages).order(updated_at: :desc).limit(limit)

    if convos.empty?
      puts "No conversations yet."
      next
    end

    convos.each do |c|
      puts "\n#{'=' * 80}"
      puts "Conversation ##{c.id}: #{c.title} (#{c.messages.count} messages)"
      puts "Created: #{c.created_at}  Updated: #{c.updated_at}"
      puts '=' * 80

      c.messages.order(:created_at).each do |m|
        puts ""
        skill_label = m.skill.present? ? " [#{m.skill}]" : ""
        puts "--- #{m.role.upcase}#{skill_label} (#{m.created_at.strftime('%H:%M:%S')}) ---"
        puts m.content

        if m.tool_calls.present? && m.tool_calls.is_a?(Array) && m.tool_calls.any?
          puts ""
          puts "  TOOL CALLS:"
          m.tool_calls.each do |tc|
            puts "    -> #{tc['name']}(#{tc['input'].to_json.truncate(120)})"
          end
        end
      end
    end
    puts "\n#{'=' * 80}"
  end

  desc "Show just the last conversation"
  task last: :environment do
    ENV["LIMIT"] = "1"
    Rake::Task["loadstone:inspect"].invoke
  end
end
