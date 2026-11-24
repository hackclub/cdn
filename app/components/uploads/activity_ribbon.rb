# frozen_string_literal: true

class Components::Uploads::ActivityRibbon < Components::Base
  include ActionView::Helpers::TextHelper

  def initialize(counts:, rows: 2, cols: 120, size: "10px")
    @counts = counts
    @rows = rows
    @cols = cols
    @size = size
  end

  def view_template
    div(
      class: "upload-activity-ribbon ribbon--#{@rows}row",
      data: { activity_ribbon: true, rows: @rows }
    ) do
      div(class: "activity-shimmer-mask", aria: { hidden: "true" })
      div(class: "activity-grid") do
        (0...@cols).each do |c|
          col_offset = (@cols - 1 - c) * @rows
          div(class: "activity-column") do
            (@rows - 1).downto(0) do |r|
              day_offset = col_offset + r
              date = Date.current - day_offset.days
              count = @counts[date] || 0
              lvl = level_for_count(count)
              render_cell(lvl, count, @size, date)
            end
          end
        end
      end
    end
  end

  private

  def level_for_count(count)
    case count
    when 0 then 0
    when 1..2 then 1
    when 3..5 then 2
    when 6..9 then 3
    else 4
    end
  end

  def render_cell(lvl, count, size, date)
    date_str = date.strftime("%b %-d, %Y")
    count_text = count == 0 ? "No uploads" : pluralize(count, "upload")

    span(
      class: "activity-cell",
      data: {
        level: lvl,
        tooltip_count: count_text,
        tooltip_date: "on #{date_str}",
        date: date.strftime("%Y-%m-%d"),
        has_uploads: (count > 0 ? "true" : "false")
      },
      aria: { label: "#{count_text} on #{date_str}" },
      tabindex: 0
    )
  end
end
