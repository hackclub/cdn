# frozen_string_literal: true

class Components::Uploads::Row < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  def initialize(upload:, compact: false, admin: false)
    @upload = upload
    @compact = compact
    @admin = admin
  end

  def view_template
    div(style: "display: flex; justify-content: space-between; align-items: #{compact ? 'center' : 'flex-start'}; gap: 16px;") do
      if compact
        compact_content
      else
        full_content
      end
    end
  end

  private

  attr_reader :upload, :compact, :admin

  def compact_content
    div(style: "flex: 1; min-width: 0;") do
      div(style: "display: block; cursor: pointer; max-width: 100%; min-width: 0;", data: { batch_select_toggle: upload.id }) do
        div(style: "display: flex; align-items: center; gap: 8px; font-size: 14px; font-weight: 500; min-width: 0; max-width: 100%;") do
          render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small, style: "flex-shrink: 0;")
          span(class: "upload-title-text") { plain upload.filename.to_s }
        end
        div(class: "upload-meta-text", style: "font-size: 12px; margin-top: 4px;") do
          plain "#{upload.human_file_size} • #{time_ago_in_words(upload.created_at)} ago"
        end
      end
    end

    div(class: "upload-row-actions", style: "display: flex; gap: 8px; align-items: center;") do
      render(Primer::Beta::ClipboardCopyButton.new(value: upload.cdn_url, size: :small, "aria-label": "Copy link")) { "Copy link" }

      render(Primer::Beta::IconButton.new(icon: :eye, tag: :a, href: upload.cdn_url, target: "_blank", rel: "noopener", size: :small, "aria-label": "View file"))

      render_delete_dialog
    end
  end

  def full_content
    div(style: "flex: 1; min-width: 0;") do
      div(style: "display: block; cursor: pointer; max-width: 100%; min-width: 0;", data: { batch_select_toggle: upload.id }) do
        div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 6px; min-width: 0; max-width: 100%;") do
          render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small, style: "flex-shrink: 0;")
          span(class: "upload-title-text") { plain upload.filename.to_s }
          render_provenance_pill
        end
        div(class: "upload-meta-text", style: "font-size: 12px;") do
          plain "#{upload.human_file_size} • #{upload.content_type} • #{time_ago_in_words(upload.created_at)} ago"
        end
      end
    end

    div(class: "upload-row-actions", style: "display: flex; gap: 8px; align-items: center;") do
      render(Primer::Beta::ClipboardCopyButton.new(value: upload.cdn_url, size: :small, "aria-label": "Copy link")) { "Copy link" }

      render(Primer::Beta::IconButton.new(icon: :eye, tag: :a, href: upload.cdn_url, target: "_blank", rel: "noopener", size: :small, "aria-label": "View file"))

      render_delete_dialog
    end
  end

  def render_delete_dialog
    render Primer::Alpha::Dialog.new(
      title: "Delete file?",
      size: :auto,
      classes: "delete-confirm-dialog"
    ) do |dialog|
      dialog.with_show_button(scheme: :danger, size: :small, "aria-label": "Delete file") do
        render Primer::Beta::Octicon.new(icon: :trash)
      end
      dialog.with_header do
        h3(style: "margin: 0; font-size: 16px; font-weight: 600; color: var(--fgColor-default); word-break: break-word; overflow-wrap: anywhere;") do
          "Delete #{upload.filename}?"
        end
      end
      dialog.with_body do
        div(style: "font-size: 14px; line-height: 1.5; color: var(--fgColor-default);") do
          p(style: "margin: 0 0 8px 0; font-size: 14px; line-height: 1.5; word-break: break-word; overflow-wrap: anywhere;") do
            plain "Are you sure you want to delete "
            strong { plain upload.filename.to_s }
            plain "?"
          end

          p(style: "margin: 0; font-size: 13px; line-height: 1.5; color: var(--fgColor-muted);") do
            plain "This action cannot be undone. This file will be permanently removed from the CDN."
          end
        end
      end
      dialog.with_footer do
        div(style: "display: flex; justify-content: flex-end; align-items: center; gap: 8px; width: 100%;") do
          button(
            type: "button",
            class: "btn",
            data: { close_dialog_id: dialog.id },
            style: "cursor: pointer;"
          ) { "Cancel" }
          form_with url: (admin ? admin_upload_path(upload) : upload_path(upload)), method: :delete, style: "display: inline;", data: { delete_upload_form: true, upload_id: upload.id, upload_filename: upload.filename.to_s } do
            button(type: "submit", class: "btn btn-danger", style: "display: inline-flex; align-items: center; gap: 6px; cursor: pointer;") do
              render Primer::Beta::Octicon.new(icon: :trash, size: :small)
              plain "Delete file"
            end
          end
        end
      end
    end
  end

  def render_provenance_pill
    render(Primer::Beta::Label.new(scheme: :secondary, classes: "upload-provenance-pill")) do
      case upload.provenance.to_s
      when "web"
        render Primer::Beta::Octicon.new(icon: :globe)
        plain "Web"
      when "api"
        render Primer::Beta::Octicon.new(icon: :terminal)
        plain "API"
      when "slack"
        raw safe(%(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" fill="currentColor" aria-hidden="true"><path d="M94.12 315.1c0 25.9-21.16 47.06-47.06 47.06S0 341 0 315.1s21.16-47.06 47.06-47.06h47.06zm23.72 0c0-25.9 21.16-47.06 47.06-47.06s47.06 21.16 47.06 47.06v117.84c0 25.9-21.16 47.06-47.06 47.06s-47.06-21.16-47.06-47.06zm47.06-188.98c-25.9 0-47.06-21.16-47.06-47.06S139 32 164.9 32s47.06 21.16 47.06 47.06v47.06zm0 23.72c25.9 0 47.06 21.16 47.06 47.06s-21.16 47.06-47.06 47.06H47.06C21.16 243.96 0 222.8 0 196.9s21.16-47.06 47.06-47.06zm188.98 47.06c0-25.9 21.16-47.06 47.06-47.06S448 171 448 196.9s-21.16 47.06-47.06 47.06h-47.06zm-23.72 0c0 25.9-21.16 47.06-47.06 47.06s-47.06-21.16-47.06-47.06V79.06c0-25.9 21.16-47.06 47.06-47.06s47.06 21.16 47.06 47.06zM283.1 385.88c25.9 0 47.06 21.16 47.06 47.06S309 480 283.1 480s-47.06-21.16-47.06-47.06v-47.06zm0-23.72c-25.9 0-47.06-21.16-47.06-47.06s21.16-47.06 47.06-47.06h117.84c25.9 0 47.06 21.16 47.06 47.06s-21.16 47.06-47.06 47.06z"/></svg>))
        plain "Slack"
      else
        render Primer::Beta::Octicon.new(icon: :history)
        plain upload.provenance.to_s.titleize
      end
    end
  end

  def file_icon_for(content_type)
    case content_type
    when /image/ then :image
    when /video/ then :video
    when /audio/ then :unmute
    when /pdf/ then :file
    when /zip|rar|tar|gz/ then :"file-zip"
    when /text|json|xml/ then :code
    else :file
    end
  end
end
