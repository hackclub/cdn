# frozen_string_literal: true

class Components::StaticPages::Home < Components::StaticPages::Base
  def initialize(stats:, user:, flavor_text:)
    @stats = stats
    @user = user
    @flavor_text = flavor_text
  end

  def view_template
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      kpi_section
      main_section
    end
  end

  private

  attr_reader :stats, :user, :flavor_text

  def header_section
    header(style: "display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 16px; padding-bottom: 24px; margin-bottom: 24px; border-bottom: 1px solid var(--borderColor-default, #d0d7de);") do
      div do
        p(style: "color: var(--fgColor-muted, #656d76); margin: 0 0 4px; font-size: 14px;") do
          plain "Welcome back, "
          strong { user&.name || "friend" }
        end
        h1(style: "font-size: 2rem; font-weight: 300; margin: 0;") { "Hack Club CDN" }
        div(style: "margin-top: 8px;") do
          render(Primer::Beta::Label.new(scheme: :secondary)) { flavor_text }
        end
      end

      div(style: "display: flex; gap: 8px; flex-wrap: wrap;") do
        a(href: helpers.docs_path("getting-started"), class: "btn") do
          render Primer::Beta::Octicon.new(icon: :book, mr: 1)
          plain "Docs"
        end
        a(href: helpers.uploads_path, class: "btn btn-primary") do
          render Primer::Beta::Octicon.new(icon: :upload, mr: 1)
          plain "Upload"
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
        quota_stat_card
      end

      # Recent uploads
      if stats[:recent_uploads].any?
        h2(style: "font-size: 14px; font-weight: 600; color: var(--fgColor-muted, #656d76); text-transform: uppercase; letter-spacing: 0.5px; margin: 24px 0 12px;") { "Recent Uploads" }
        recent_uploads_list
      end
    end
  end

  def recent_uploads_list
    render Primer::Beta::BorderBox.new do |box|
      stats[:recent_uploads].each do |upload|
        box.with_row do
          render Components::Uploads::Row.new(upload: upload, compact: true)
        end
      end
    end
  end

  def quota_stat_card
    quota_data = stats[:quota]
    available = quota_data[:available]
    limit = quota_data[:storage_limit]
    percentage = quota_data[:percentage_used]

    # Color based on usage
    color = if percentage >= 100
      "var(--fgColor-danger)"
    elsif percentage >= 80
      "var(--fgColor-attention)"
    else
      "var(--fgColor-success)"
    end

    progress_color = if percentage >= 100
      "var(--bgColor-danger-emphasis)"
    elsif percentage >= 80
      "var(--bgColor-attention-emphasis)"
    else
      "var(--bgColor-success-emphasis)"
    end

    div(style: "padding: 14px; background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px;") do
      div(style: "display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;") do
        div do
          p(style: "font-size: 11px; color: var(--fgColor-muted, #656d76); margin: 0 0 4px; text-transform: uppercase; letter-spacing: 0.3px;") { "Available storage" }
          span(style: "font-size: 28px; font-weight: 600; line-height: 1; color: #{color};") do
            helpers.number_to_human_size(available)
          end
          p(style: "font-size: 11px; color: var(--fgColor-muted); margin: 4px 0 0;") do
            plain "of #{helpers.number_to_human_size(limit)}"
          end
        end
        span(style: "color: var(--fgColor-muted, #656d76);") do
          render Primer::Beta::Octicon.new(icon: :"shield-check", size: :small)
        end
      end
      # Progress bar
      div(style: "background: var(--bgColor-muted); border-radius: 3px; height: 6px; overflow: hidden;") do
        div(style: "background: #{progress_color}; height: 100%; width: #{[ percentage, 100 ].min}%;")
      end
    end
  end

  def main_section
    div(style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 24px;") do
      resources_panel
    end
  end
end
