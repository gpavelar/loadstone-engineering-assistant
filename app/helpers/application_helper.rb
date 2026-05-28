module ApplicationHelper
  # Configure these via env vars so this repo carries no org-specific URLs.
  # JIRA_HOST: your Atlassian Cloud hostname (e.g. "your-org.atlassian.net")
  # GITHUB_ORG: your GitHub org (e.g. "your-org")
  # GITHUB_DEFAULT_REPO: default repo for "PR #1234" auto-linking when no repo context is given
  JIRA_BASE = "https://#{ENV.fetch('JIRA_HOST', 'your-org.atlassian.net')}/browse".freeze
  GITHUB_BASE = "https://github.com".freeze
  GITHUB_DEFAULT_REPO = "#{ENV.fetch('GITHUB_ORG', 'your-org')}/#{ENV.fetch('GITHUB_DEFAULT_REPO', 'your-repo')}".freeze

  def render_markdown(text)
    return "" if text.blank?

    # Auto-link Jira tickets (PROJ-1234, PROJ-123, etc.) before markdown rendering
    linked = auto_link_jira(text)

    # Auto-link GitHub PR references (#1234 in context of a repo, or explicit PR URLs)
    linked = auto_link_github_prs(linked)

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      filter_html: true,
      no_images: false,
      no_links: false,
      no_styles: true,
      safe_links_only: true
    )
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      tables: true,
      autolink: true,
      strikethrough: true,
      no_intra_emphasis: true
    )
    html = markdown.render(linked)
    # Make all links open in new tab
    html = html.gsub("<a ", '<a target="_blank" rel="noopener" ')
    sanitize(html, tags: allowed_tags, attributes: allowed_attributes)
  end

  def status_badge(status)
    color = case status
    when "done"    then "bg-green-800 text-green-200"
    when "failed"  then "bg-red-800 text-red-200"
    when "running" then "bg-yellow-800 text-yellow-200"
    else "bg-gray-700 text-gray-300"
    end
    content_tag(:span, status, class: "text-xs px-2 py-0.5 rounded #{color}")
  end

  def mode_chip(value, label, active: false)
    classes = "px-2 py-0.5 rounded border border-gray-700 hover:bg-gray-700"
    classes += " bg-blue-700 text-blue-100" if active
    content_tag(:button, label,
                type: "button",
                data: {
                  action: "mode-picker#select",
                  mode_picker_value_param: value,
                  mode_picker_steering_param: Skills::InvestigationModes.steering_for(value),
                  mode_picker_label_param: label
                },
                class: classes)
  end

  private

  # Turn ABC-12345 into [ABC-12345](https://<jira-host>/browse/ABC-12345)
  # unless already inside a markdown link.
  def auto_link_jira(text)
    text.gsub(/(?<!\[)\b([A-Z]{2,5}-\d{3,6})\b(?!\])(?!\()/) do |match|
      "[#{match}](#{JIRA_BASE}/#{match})"
    end
  end

  # Turn "PR #1234" into clickable links pointing at the default repo configured
  # via GITHUB_DEFAULT_REPO. Leaves already-linked text alone.
  def auto_link_github_prs(text)
    text.gsub(/(?:PR\s*)#(\d{3,6})\b/) do |match|
      number = $1
      "[#{match}](#{GITHUB_BASE}/#{GITHUB_DEFAULT_REPO}/pull/#{number})"
    end
  end

  def allowed_tags
    %w[p h1 h2 h3 h4 h5 h6 ul ol li a strong em code pre blockquote table thead tbody tr th td hr br span del]
  end

  def allowed_attributes
    %w[href target rel class id]
  end
end
