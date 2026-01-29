# frozen_string_literal: true

class Components::StaticPages::Base < Components::Base
  def stat_card(title, value, icon)
    div(style: "padding: 14px; background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px;") do
      div(style: "display: flex; justify-content: space-between; align-items: flex-start;") do
        div do
          p(style: "font-size: 11px; color: var(--fgColor-muted, #656d76); margin: 0 0 4px; text-transform: uppercase; letter-spacing: 0.3px;") { title }
          span(style: "font-size: 28px; font-weight: 600; line-height: 1;") { value.to_s }
        end
        span(style: "color: var(--fgColor-muted, #656d76);") do
          render Primer::Beta::Octicon.new(icon: icon, size: :small)
        end
      end
    end
  end

  def link_panel(title, links)
    div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
      div(style: "padding: 12px 16px; border-bottom: 1px solid var(--borderColor-default, #d0d7de); background: var(--bgColor-muted, #f6f8fa);") do
        h3(style: "font-size: 14px; font-weight: 600; margin: 0;") { title }
      end
      div(style: "padding: 8px 0;") do
        links.each do |link|
          a(
            href: link[:href],
            target: link[:href].start_with?("http") ? "_blank" : nil,
            rel: link[:href].start_with?("http") ? "noopener" : nil,
            style: "display: flex; align-items: center; gap: 12px; padding: 10px 16px; text-decoration: none; color: inherit;"
          ) do
            span(style: "color: var(--fgColor-muted, #656d76);") do
              render Primer::Beta::Octicon.new(icon: link[:icon], size: :small)
            end
            span(style: "font-size: 14px;") { link[:label] }
          end
        end
      end
    end
  end

  def resources_panel
    links = [
      { label: "Documentation", href: doc_path("getting-started"), icon: :book },
      { label: "GitHub Repo", href: "https://github.com/hackclub/cdn", icon: :"mark-github" },
      { label: "Use via Slack", href: "https://hackclub.enterprise.slack.com/archives/C016DEDUL87", icon: :"comment-discussion" },
      { label: "Help with development?", href: "https://hackclub.enterprise.slack.com/archives/C0ACGUA6XTJ", icon: :heart },
      { label: "Report an Issue", href: "https://github.com/hackclub/cdn/issues", icon: :"issue-opened" }
    ]
    link_panel("Resources", links)
  end
end
