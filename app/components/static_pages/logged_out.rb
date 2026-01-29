# frozen_string_literal: true

class Components::StaticPages::LoggedOut < Components::StaticPages::Base
  def initialize(stats:)
    @stats = stats
  end

  def view_template
    div(style: "max-width: 1200px; margin: 0 auto; padding: 48px 24px 24px;") do
      header_section
      stats_section
      main_section
    end
  end

  private

  attr_reader :stats

  def header_section
    header(style: "display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 16px; padding-bottom: 24px; margin-bottom: 24px; border-bottom: 1px solid var(--borderColor-default, #d0d7de);") do
      div do
        h1(style: "font-size: 2rem; font-weight: 300; margin: 0 0 8px;") do
          plain "Hack Club CDN"
          sup(style: "font-size: 0.5em; margin-left: 4px;") { "v4" }
        end
        p(style: "color: var(--fgColor-muted, #656d76); margin: 0; max-width: 600px;") do
          plain "File hosting for Hack Clubbers."
        end
      end

      div(style: "display: flex; gap: 8px; flex-wrap: wrap;") do
        button_to "Sign in with Hack Club", "/auth/hack_club", method: :post, class: "btn btn-primary", data: { turbo: false }
      end
    end
  end

  def stats_section
    div(style: "margin-bottom: 32px;") do
      h2(style: "font-size: 14px; font-weight: 600; color: var(--fgColor-muted, #656d76); text-transform: uppercase; letter-spacing: 0.5px; margin: 0 0 12px;") { "State of the Platform:" }
      div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 24px;") do
        stat_card("Total files", stats[:total_files], :archive)
        stat_card("Storage used", stats[:storage_formatted], :database)
        stat_card("Users", stats[:total_users], :people)
        stat_card("Files this week", stats[:files_this_week], :zap)
      end

      h2(style: "font-size: 14px; font-weight: 600; color: var(--fgColor-muted, #656d76); text-transform: uppercase; letter-spacing: 0.5px; margin: 24px 0 12px;") { "New in V4:" }
      div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;") do
        feature_card(:lock, "Invincible", "Backups of the underlying storage exist.")
        feature_card(:link, "No broken links, this time?", "it lives on a domain! that we own!")
        feature_card(:"shield-check", "Hopefully reliable", 'Backed by the award-winning "cc @nora" service guarantee.')
      end
    end
  end

  def feature_card(icon, title, description)
    div(style: "padding: 14px; background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px;") do
      div(style: "display: flex; align-items: center; gap: 10px; margin-bottom: 6px;") do
        span(style: "color: var(--fgColor-muted, #656d76);") do
          render Primer::Beta::Octicon.new(icon: icon, size: :small)
        end
        h3(style: "font-size: 14px; font-weight: 600; margin: 0;") { title }
      end
      p(style: "font-size: 12px; color: var(--fgColor-muted, #656d76); margin: 0;") { description }
    end
  end

  def main_section
    div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 24px;") do
      resources_panel
    end
  end
end
