# frozen_string_literal: true

class Components::StaticPages::Home < Components::StaticPages::Base
  def initialize(stats:, user:)
    @stats = stats
    @user = user
  end

  def view_template
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      kpi_section
      main_section
    end
  end

  private

  attr_reader :stats, :user

  def header_section
    header(style: "display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 16px; padding-bottom: 24px; margin-bottom: 24px; border-bottom: 1px solid var(--borderColor-default, #d0d7de);") do
      div do
        p(style: "color: var(--fgColor-muted, #656d76); margin: 0 0 4px; font-size: 14px;") do
          plain "Welcome back, "
          strong { user&.name || "friend" }
        end
        h1(style: "font-size: 2rem; font-weight: 300; margin: 0;") { "Your CDN Stash" }
      end

      div(style: "display: flex; gap: 8px; flex-wrap: wrap;") do
        a(href: "https://github.com/hackclub/cdn", target: "_blank", rel: "noopener", class: "btn") do
          render Primer::Beta::Octicon.new(icon: :"mark-github", mr: 1)
          plain "View on GitHub"
        end
        a(href: "https://app.slack.com/client/T0266FRGM/C016DEDUL87", target: "_blank", rel: "noopener", class: "btn btn-primary") do
          render Primer::Beta::Octicon.new(icon: :"comment-discussion", mr: 1)
          plain "Join #cdn"
        end
      end
    end
  end

  def kpi_section
    div(style: "margin-bottom: 32px;") do
      # Your stats section
      h2(style: "font-size: 14px; font-weight: 600; color: var(--fgColor-muted, #656d76); text-transform: uppercase; letter-spacing: 0.5px; margin: 0 0 12px;") { "Your Stats" }
      div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 24px;") do
        stat_card("Total files", stats[:total_files], :archive)
        stat_card("Storage used", stats[:storage_formatted], :database)
        stat_card("Uploaded today", stats[:files_today], :upload)
        stat_card("This week", stats[:files_this_week], :zap)
      end

      # Recent uploads
      if stats[:recent_uploads].any?
        h2(style: "font-size: 14px; font-weight: 600; color: var(--fgColor-muted, #656d76); text-transform: uppercase; letter-spacing: 0.5px; margin: 24px 0 12px;") { "Recent Uploads" }
        recent_uploads_list
      end
    end
  end

  def recent_uploads_list
    div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
      stats[:recent_uploads].each_with_index do |upload, index|
        render Components::Uploads::Row.new(upload: upload, index: index, compact: true)
      end
    end
  end

  def main_section
    div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 24px;") do
      resources_panel
    end
  end
end
