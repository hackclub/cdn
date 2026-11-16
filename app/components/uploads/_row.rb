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
          render(Primer::Beta::Label.new(scheme: :secondary, style: "flex-shrink: 0;")) { plain upload.provenance.titleize }
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
          form_with url: (admin ? admin_upload_path(upload) : upload_path(upload)), method: :delete, style: "display: inline;" do
            button(type: "submit", class: "btn btn-danger", style: "display: inline-flex; align-items: center; gap: 6px; cursor: pointer;") do
              render Primer::Beta::Octicon.new(icon: :trash, size: :small)
              plain "Delete file"
            end
          end
        end
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
