# frozen_string_literal: true

class Components::Uploads::Index < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  register_output_helper :paginate


  def initialize(uploads:, query: nil)
    @uploads = uploads
    @query = query
  end

  def view_template
    dropzone_form
    div(class: "uploads-container is-loaded", data: { uploads_container: true }, style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      upload_hero_card
      uploads_history_header
      search_section
      uploads_list
      pagination_section if uploads.respond_to?(:total_pages) && uploads.total_pages > 1
    end
    batch_delete_bar
    batch_delete_modal
  end

  private

  attr_reader :uploads, :query

  def header_section
    header(style: "margin-bottom: 24px;") do
      h1(style: "font-size: 2rem; font-weight: 600; margin: 0; color: var(--fgColor-default);") { "Uploads" }
      p(style: "color: var(--fgColor-muted, #656d76); margin: 6px 0 0; font-size: 14px;") do
        "Drop files to upload, paste from clipboard, or browse your files."
      end
    end
  end

  def upload_hero_card
    div(
      class: "Box upload-card",
      data: { upload_card: true },
      style: "position: relative; background: var(--bgColor-default); border: 1px solid var(--borderColor-default); border-radius: 6px; overflow: hidden; margin-bottom: 32px;"
    ) do
      div(
        class: "upload-hero-stage",
        data: { hero_stage: true }
      ) do
        # Resting view
        div(
          class: "upload-resting-view",
          data: { resting_view: true }
        ) do
          div(style: "margin-bottom: 10px; color: var(--fgColor-muted);") do
            render Primer::Beta::Octicon.new(icon: :upload, size: :medium)
          end

          h3(style: "font-size: 16px; font-weight: 600; margin: 0 0 10px 0; color: var(--fgColor-default);") do
            "Drag and drop or paste directly"
          end

          div(style: "display: flex; gap: 8px; align-items: center; justify-content: center; margin-bottom: 16px;") do
            span(class: "Label Label--secondary", style: "font-size: 11px; padding: 2px 7px;") { "Up to 40 files" }
            span(class: "Label Label--secondary", style: "font-size: 11px; padding: 2px 7px;") { "Max #{max_file_size_formatted} each" }
          end

          div(style: "width: 140px; height: 1px; background: var(--borderColor-default); margin-bottom: 18px;")

          label(
            for: "dropzone-file-input",
            class: "btn btn-primary",
            style: "cursor: pointer; padding: 7px 20px; font-size: 14px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px;"
          ) do
            render Primer::Beta::Octicon.new(icon: :upload, size: :small)
            plain "Upload files"
          end
        end

        # Dropzone view with mascot
        render_orph_drop_card
      end

      # Activity graph ribbon
      div(style: "width: 100%; margin-top: 4px; margin-bottom: 18px; padding: 0 8px; box-sizing: border-box;") do
        render_activity_ribbon(rows: 2, size: "10px", gap: "3px")
      end
    end
  end

  def render_orph_drop_card
    div(
      class: "upload-orph-view dropzone-container",
      data: { orph_view: true },
      aria: { hidden: "true" }
    ) do
      div(class: "orph-sunburst") do
        raw safe(render_sunburst_svg)
      end

      div(class: "orph-stage", data: { orph_stage: true }) do
        div(class: "orph-character", data: { orph_character: true }) do
          img(
            src: "/orph-closed-mouth.svg",
            class: "orph-graphic orph-closed",
            alt: "Orph closed mouth"
          )
          img(
            src: "/orph-open-mouth.svg",
            class: "orph-graphic orph-open",
            alt: "Orph open mouth"
          )
          div(class: "orph-pupil orph-pupil-left", data: { orph_pupil_left: true })
          div(class: "orph-pupil orph-pupil-right", data: { orph_pupil_right: true })
          div(class: "orph-speech-bubble", data: { orph_bubble: true }) { "Feed me files!" }
        end
      end

      # Right side: Content
      div(class: "dropzone-content", data: { orph_content: true }) do
        div(class: "dropzone-upload-badge") do
          raw safe(%(<svg viewBox="0 0 16 16" fill="currentColor" style="width: 14px; height: 14px;"><path d="M7.75 2a.75.75 0 0 1 .75.75V7h2.25a.75.75 0 0 1 .53 1.28l-3 3a.75.75 0 0 1-1.06 0l-3-3A.75.75 0 0 1 4.75 7H7V2.75A.75.75 0 0 1 7.75 2Z"></path><path d="M2.5 10.75a.75.75 0 0 1 .75.75v1a.5.5 0 0 0 .5.5h8.5a.5.5 0 0 0 .5-.5v-1a.75.75 0 0 1 1.5 0v1A2 2 0 0 1 12.25 14.5h-8.5A2 2 0 0 1 1.75 12.5v-1a.75.75 0 0 1 .75-.75Z"></path></svg>))
          span { "Drag & Drop" }
        end

        h2(class: "dropzone-title", data: { dropzone_title: true }) { "Feed me, mortal" }

        div(class: "dropzone-meta") do
          span(class: "dropzone-tag") { "Up to 40 files" }
          span(class: "dropzone-tag") { "Max #{max_file_size_formatted} each" }
        end
      end
    end
  end

  def render_sunburst_svg
    <<~SVG
      <svg viewBox="0 0 800 240" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none">
        <defs>
          <!-- Smooth horizontal luminance base fade toward right, finishing before half (47%) -->
          <linearGradient id="sunburst-hfade" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#fff" stop-opacity="1" />
            <stop offset="18%" stop-color="#fff" stop-opacity="1" />
            <stop offset="26%" stop-color="#fff" stop-opacity="0.85" />
            <stop offset="33%" stop-color="#fff" stop-opacity="0.55" />
            <stop offset="40%" stop-color="#fff" stop-opacity="0.22" />
            <stop offset="44%" stop-color="#fff" stop-opacity="0.05" />
            <stop offset="47%" stop-color="#000" stop-opacity="0" />
            <stop offset="100%" stop-color="#000" stop-opacity="0" />
          </linearGradient>

          <!-- 4x4 Ordered Bayer / Stipple Dither Dot Pattern -->
          <pattern id="sunburst-dither-dots" width="4" height="4" patternUnits="userSpaceOnUse">
            <rect x="0" y="0" width="1" height="1" fill="#fff" />
            <rect x="2" y="2" width="1" height="1" fill="#fff" />
          </pattern>

          <mask id="sunburst-dither-mask">
            <!-- Continuous gradient base -->
            <rect x="0" y="0" width="800" height="240" fill="url(#sunburst-hfade)" />
            <!-- Dither stipple dots in active zone: x=150 to x=376 (ends before 48%, well before half 400) -->
            <rect x="150" y="0" width="226" height="240" fill="url(#sunburst-dither-dots)" opacity="0.28" />
          </mask>
        </defs>
        <g mask="url(#sunburst-dither-mask)" class="orph-sunburst-rays">
          <polygon points="176.0,120.0 972.9,49.4 972.9,190.6" />
          <polygon points="176.0,120.0 939.2,359.7 885.2,490.2" />
          <polygon points="176.0,120.0 789.4,633.6 689.6,733.4" />
          <polygon points="176.0,120.0 546.2,829.2 415.7,883.2" />
          <polygon points="176.0,120.0 246.6,916.9 105.4,916.9" />
          <polygon points="176.0,120.0 -63.7,883.2 -194.2,829.2" />
          <polygon points="176.0,120.0 -337.6,733.4 -437.4,633.6" />
          <polygon points="176.0,120.0 -533.2,490.2 -587.2,359.7" />
          <polygon points="176.0,120.0 -620.9,190.6 -620.9,49.4" />
          <polygon points="176.0,120.0 -587.2,-119.7 -533.2,-250.2" />
          <polygon points="176.0,120.0 -437.4,-393.6 -337.6,-493.4" />
          <polygon points="176.0,120.0 -194.2,-589.2 -63.7,-643.2" />
          <polygon points="176.0,120.0 105.4,-676.9 246.6,-676.9" />
          <polygon points="176.0,120.0 415.7,-643.2 546.2,-589.2" />
          <polygon points="176.0,120.0 689.6,-493.4 789.4,-393.6" />
          <polygon points="176.0,120.0 885.2,-250.2 939.2,-119.7" />
        </g>
      </svg>
    SVG
  end

  def uploads_history_header
    count = uploads.respond_to?(:total_count) ? uploads.total_count : uploads.size

    div(style: "display: flex; align-items: center; gap: 8px; margin: 32px 0 16px;") do
      h2(style: "font-size: 1.5rem; font-weight: 600; margin: 0; color: var(--fgColor-default);", data: { uploads_history: true }) { "Uploads History" }
      render(Primer::Beta::Label.new(scheme: :secondary, data: { uploads_total_count: true })) { pluralize(count, "file") }
    end
  end

  def render_activity_ribbon(rows: 2, size: "10px", gap: "3px")
    user_id = current_user.respond_to?(:id) ? current_user.id : "guest"
    cache_key = ["user_activity_ribbon_html", user_id, Date.current.to_s, rows]

    ribbon_html = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      counts = if current_user.respond_to?(:uploads)
        current_user.uploads.where("created_at >= ?", 240.days.ago).group("DATE(created_at)").count.transform_keys do |k|
          k.is_a?(String) ? Date.parse(k) : k
        end
      else
        {}
      end

      Components::Uploads::ActivityRibbon.new(
        counts: counts,
        rows: rows,
        cols: 120,
        size: size
      ).call
    end

    raw safe(ribbon_html)
  end

  def search_section
    div(style: "margin-bottom: 24px;") do
      form_with url: uploads_path, method: :get do
        div(style: "display: flex; gap: 12px;") do
          input(
            type: "search",
            name: "query",
            placeholder: "Search files...",
            value: query,
            class: "form-control",
            style: "flex: 1; max-width: 400px;"
          )
          button(type: "submit", class: "btn") do
            render Primer::Beta::Octicon.new(icon: :search, mr: 1)
            plain "Search"
          end
        end
      end
    end
  end

  def uploads_list
    div(class: "uploads-timeline-wrapper", data: { timeline_wrapper: true }) do
      skeleton_placeholder_timeline

      if uploads.any?
        real_populated_timeline
      else
        empty_state
      end
    end
  end

  def skeleton_placeholder_timeline
    div(class: "uploads-skeleton-placeholder", aria: { hidden: "true" }) do
      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 16px; padding: 4px 0;") do
        div(class: "skeleton-pill", style: "width: 16px; height: 16px; border-radius: 3px;")
        div(class: "skeleton-pill", style: "width: 70px; height: 14px; border-radius: 4px;")
      end

      div(class: "uploads-timeline", style: "margin-top: 0;") do
        2.times do |g|
          div(class: "timeline-date-group") do
            div(class: "timeline-date-header") do
              span(class: "timeline-node-icon") do
                render Primer::Beta::Octicon.new(icon: :"git-commit", size: :small)
              end
              div(class: "skeleton-pill", style: "width: #{g == 0 ? 120 : 105}px; height: 16px; border-radius: 4px; margin-right: 8px;")
              div(class: "skeleton-pill", style: "width: 46px; height: 18px; border-radius: 10px;")
            end

            render Primer::Beta::BorderBox.new do |box|
              3.times do |r|
                box.with_row do
                  div(style: "display: flex; align-items: flex-start; gap: 12px; padding: 4px 0;") do
                    div(class: "skeleton-pill", style: "width: 14px; height: 14px; border-radius: 3px; margin-top: 4px; flex-shrink: 0;")
                    div(style: "color: var(--fgColor-muted, #656d76); margin-top: 2px; flex-shrink: 0;") do
                      render Primer::Beta::Octicon.new(icon: :file, size: :small)
                    end
                    div(style: "flex: 1; min-width: 0;") do
                      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;") do
                        div(class: "skeleton-pill", style: "width: #{[180, 240, 210, 195][(g * 3 + r) % 4]}px; max-width: 60%; height: 14px; border-radius: 4px;")
                        div(class: "skeleton-pill", style: "width: 54px; height: 18px; border-radius: 10px;")
                      end
                      div(class: "skeleton-pill", style: "width: #{[120, 145, 110, 135][(g * 3 + r) % 4]}px; max-width: 40%; height: 11px; border-radius: 3px;")
                    end
                    div(style: "display: flex; gap: 8px; align-items: center;") do
                      div(class: "skeleton-pill", style: "width: 28px; height: 28px; border-radius: 6px;")
                      div(class: "skeleton-pill", style: "width: 28px; height: 28px; border-radius: 6px;")
                      div(class: "skeleton-pill", style: "width: 28px; height: 28px; border-radius: 6px;")
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def real_populated_timeline
    div(class: "uploads-real-timeline") do
      item_idx = 0

      div(class: "select-all-row timeline-item", style: "--item-index: #{item_idx += 1}; display: flex; align-items: center; gap: 8px; margin-bottom: 16px; padding: 4px 0;") do
        input(
          type: "checkbox",
          id: "select-all-uploads",
          data: { batch_select_all: true },
          style: "cursor: pointer;"
        )
        label(for: "select-all-uploads", style: "font-size: 13px; color: var(--fgColor-muted, #656d76); cursor: pointer;") do
          plain "Select all"
        end
      end

      div(class: "uploads-timeline") do
        uploads.group_by { |upload| upload.created_at.to_date }.each do |date, date_uploads|
          date_key = date.strftime("%Y-%m-%d")
          item_idx += 1
          current_date_idx = item_idx

          div(class: "timeline-date-group", id: "date-group-#{date_key}", data: { date_group: date_key }) do
            div(class: "timeline-date-header timeline-item", style: "--item-index: #{current_date_idx};") do
              span(class: "timeline-node-icon") do
                render Primer::Beta::Octicon.new(icon: :"git-commit", size: :small)
              end
              if date == Date.current
                h3(class: "timeline-date-title") do
                  plain "Today "
                  span(style: "color: var(--fgColor-muted, #656d76); font-weight: 400; font-size: 13px;") do
                    plain "— #{date.strftime('%b %-d, %Y')}"
                  end
                end
              elsif date == Date.yesterday
                h3(class: "timeline-date-title") do
                  plain "Yesterday "
                  span(style: "color: var(--fgColor-muted, #656d76); font-weight: 400; font-size: 13px;") do
                    plain "— #{date.strftime('%b %-d, %Y')}"
                  end
                end
              else
                h3(class: "timeline-date-title") do
                  date.strftime("%b %-d, %Y")
                end
              end
              render(Primer::Beta::Label.new(scheme: :secondary, data: { date_group_count: true })) { pluralize(date_uploads.size, "file") }
            end

            render Primer::Beta::BorderBox.new do |box|
              date_uploads.each do |upload|
                item_idx += 1
                render_real_upload_row(box, upload, item_idx)
              end
            end
          end
        end
      end
    end
  end

  def render_real_upload_row(box, upload, row_idx)
    box.with_row do
      div(class: "upload-row-item timeline-item", style: "display: flex; align-items: flex-start; gap: 12px; --item-index: #{row_idx};", data: { item_index: row_idx, upload_row_id: upload.id }) do
        input(
          type: "checkbox",
          name: "ids[]",
          value: upload.id,
          form: "batch-delete-form",
          data: {
            batch_select_item: true,
            upload_id: upload.id,
            created_at: upload.created_at.to_date.to_s,
            formatted_date: upload.created_at.strftime("%b %-d, %Y")
          },
          style: "margin-top: 6px; cursor: pointer;"
        )
        div(style: "flex: 1; min-width: 0;") do
          render Components::Uploads::Row.new(upload: upload, compact: false)
        end
      end
    end
  end

  def empty_state
    render Primer::Beta::Blankslate.new(border: true) do |component|
      component.with_visual_icon(icon: query.present? ? :search : :upload, size: :medium)
      component.with_heading(tag: :h2) do
        query.present? ? "No files found" : "No uploads yet"
      end
      component.with_description do
        if query.present?
          "Try a different search query"
        else
          "Files you upload will appear here in your uploads history."
        end
      end
    end
  end

  def pagination_section
    div(style: "margin-top: 24px; text-align: center;") do
      paginate uploads
    end
  end

  def dropzone_form
    form_with url: uploads_path, method: :post, multipart: true, data: { dropzone_form: true } do
      input(type: "file", name: "files[]", id: "dropzone-file-input", multiple: true, data: { dropzone_input: true }, style: "display: none;")
    end
  end

  def batch_delete_bar
    div(id: "batch-delete-bar", data: { batch_bar: true }, style: "display: none; position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%); background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 12px; padding: 12px 20px; z-index: 100; box-shadow: 0 8px 24px rgba(0,0,0,0.12); min-width: 320px; max-width: 600px;") do
      div(style: "display: flex; align-items: center; gap: 16px;") do
        span(data: { batch_count: true }, style: "font-size: 14px; font-weight: 600; white-space: nowrap;") { "0 selected" }
        div(style: "flex: 1;")
        button(type: "button", data: { batch_deselect: true }, class: "btn btn-sm", style: "white-space: nowrap;") { "Deselect" }
        form_with url: destroy_batch_uploads_path, method: :delete, id: "batch-delete-form", data: { batch_delete_form: true } do
          button(type: "button", class: "btn btn-sm btn-danger", data: { batch_trigger_modal: true }, style: "white-space: nowrap;") do
            render Primer::Beta::Octicon.new(icon: :trash, mr: 1)
            plain "Delete"
          end
        end
      end
    end
  end

  def batch_delete_modal
    div(
      id: "batch-delete-modal",
      data: { batch_modal: true },
      style: "display: none; position: fixed; inset: 0; z-index: 1000; align-items: center; justify-content: center;"
    ) do
      # Backdrop overlay
      div(
        class: "batch-modal-backdrop",
        data: { batch_modal_close: true },
        style: "position: absolute; inset: 0; background: rgba(31, 35, 40, 0.4); backdrop-filter: blur(2px);"
      )

      # Modal Card
      div(
        class: "batch-modal-card Box",
        role: "dialog",
        aria: { modal: "true", labelledby: "batch-modal-title" },
        style: "position: relative; z-index: 1; width: min(480px, calc(100vw - 32px)); background: var(--bgColor-default); border: 1px solid var(--borderColor-default); border-radius: 12px; box-shadow: 0 16px 36px rgba(0, 0, 0, 0.28); overflow: hidden; display: flex; flex-direction: column;"
      ) do
        # Header
        div(style: "padding: 16px 20px; border-bottom: 1px solid var(--borderColor-muted); display: flex; align-items: center; justify-content: space-between;") do
          h3(id: "batch-modal-title", data: { batch_modal_title: true }, style: "font-size: 16px; font-weight: 600; margin: 0; color: var(--fgColor-default);") do
            "Delete selected files?"
          end
          button(
            type: "button",
            class: "close-button",
            data: { batch_modal_close: true },
            aria: { label: "Close" },
            style: "background: none; border: none; cursor: pointer; color: var(--fgColor-muted); padding: 4px; display: inline-flex; align-items: center;"
          ) do
            render Primer::Beta::Octicon.new(icon: :x)
          end
        end

        # Body
        div(style: "padding: 20px; font-size: 14px; line-height: 1.5; color: var(--fgColor-default);") do
          p(data: { batch_modal_prompt: true }, style: "margin: 0 0 12px 0; font-size: 14px; line-height: 1.5;")

          div(style: "padding: 10px 12px; background: var(--bgColor-danger-muted, #ffebe9); border: 1px solid var(--borderColor-danger-muted, rgba(255, 129, 130, 0.4)); border-radius: 6px; font-size: 13px; color: var(--fgColor-danger, #cf222e); margin-bottom: 16px; display: flex; gap: 8px; align-items: flex-start;") do
            div(style: "margin-top: 1px; flex-shrink: 0;") { render Primer::Beta::Octicon.new(icon: :"alert-fill", size: :small) }
            div { "This action cannot be undone. These files will be permanently removed from the CDN." }
          end

          div(data: { batch_modal_confirm_section: true }) do
            p(style: "margin: 0 0 8px 0; font-size: 13px; color: var(--fgColor-muted);") do
              plain "To continue, type "
              code(style: "font-weight: 600; padding: 2px 6px; background: var(--bgColor-muted, #f6f8fa); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 4px; color: var(--fgColor-default); font-family: ui-monospace, SFMono-Regular, monospace;") { "confirm" }
              plain " below:"
            end

            input(
              type: "text",
              class: "form-control input-block",
              data: { batch_modal_input: true },
              placeholder: "confirm",
              autocomplete: "off",
              spellcheck: "false",
              style: "width: 100%; box-sizing: border-box; padding: 6px 12px; font-size: 14px;"
            )
          end
        end

        # Footer
        div(style: "padding: 12px 20px; background: var(--bgColor-muted, #f6f8fa); border-top: 1px solid var(--borderColor-muted); display: flex; justify-content: flex-end; gap: 8px;") do
          button(
            type: "button",
            class: "btn",
            data: { batch_modal_close: true },
            style: "cursor: pointer;"
          ) { "Cancel" }

          button(
            type: "button",
            class: "btn btn-danger",
            data: { batch_modal_confirm_btn: true },
            disabled: true,
            style: "cursor: not-allowed; opacity: 0.6; display: inline-flex; align-items: center; gap: 6px;"
          ) do
            render Primer::Beta::Octicon.new(icon: :trash, size: :small)
            span(data: { batch_modal_confirm_btn_text: true }) { "Delete files" }
          end
        end
      end
    end
  end

  def max_file_size_formatted
    if current_user.present?
      policy = QuotaService.new(current_user).current_policy
      ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size).delete(" ")
    else
      "100MB"
    end
  rescue StandardError
    "100MB"
  end
end
