# frozen_string_literal: true

class Components::Uploads::Row < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  def initialize(upload:, index: 0, compact: false, admin: false)
    @upload = upload
    @index = index
    @compact = compact
    @admin = admin
  end

  def view_template
    div(
      style: "padding: #{compact ? '12px 16px' : '16px'}; #{index > 0 ? 'border-top: 1px solid var(--borderColor-default, #d0d7de);' : ''}",
      data: { upload_id: upload.id }
    ) do
      div(style: "display: flex; justify-content: space-between; align-items: #{compact ? 'center' : 'flex-start'}; gap: 16px;") do
        if compact
          compact_content
        else
          full_content
        end
      end
    end
  end

  private

  attr_reader :upload, :index, :compact, :admin

  def compact_content
    div(style: "flex: 1; min-width: 0;") do
      div(style: "font-size: 14px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;") do
        render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small, mr: 1)
        plain upload.filename.to_s
      end
      div(style: "font-size: 12px; color: var(--fgColor-muted, #656d76); margin-top: 4px;") do
        plain "#{upload.human_file_size} • #{time_ago_in_words(upload.created_at)} ago"
      end
    end
    
    div(style: "display: flex; gap: 8px; align-items: center;") do
      a(href: upload.cdn_url, target: "_blank", rel: "noopener", class: "btn btn-sm") do
        plain "View"
      end

      render_delete_dialog
    end
  end

  def full_content
    div(style: "flex: 1; min-width: 0;") do
      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;") do
        render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small)
        div(style: "font-size: 14px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;") do
          plain upload.filename.to_s
        end
        span(
          style: "font-size: 12px; padding: 2px 8px; background: var(--bgColor-muted, #f6f8fa); border-radius: 12px; color: var(--fgColor-muted, #656d76);"
        ) do
          plain upload.provenance.titleize
        end
      end
      div(style: "font-size: 12px; color: var(--fgColor-muted, #656d76);") do
        plain "#{upload.human_file_size} • #{upload.content_type} • #{time_ago_in_words(upload.created_at)} ago"
      end
    end

    div(style: "display: flex; gap: 8px; align-items: center;") do
      a(href: upload.cdn_url, target: "_blank", rel: "noopener", class: "btn btn-sm") do
        render Primer::Beta::Octicon.new(icon: :link, mr: 1)
        plain "View"
      end

      render_delete_dialog
    end
  end

  def render_delete_dialog
    render Primer::Alpha::Dialog.new(title: "Delete file?", size: :medium) do |dialog|
      dialog.with_show_button(scheme: :danger, size: :small) do
        render Primer::Beta::Octicon.new(icon: :trash)
      end
      dialog.with_header(variant: :large) do
        h1(style: "margin: 0;") { "Delete #{upload.filename}?" }
      end
      dialog.with_body do
        p(style: "margin: 0;") do
          plain "This action cannot be undone. The file will be permanently removed from the CDN."
        end
      end
      dialog.with_footer do
        div(style: "display: flex; justify-content: flex-end; gap: 8px;") do
          form_with url: (admin ? admin_upload_path(upload) : upload_path(upload)), method: :delete, style: "display: inline;" do
            button(type: "submit", class: "btn btn-danger") do
              plain "Delete"
            end
          end
        end
      end
    end
  end

  def file_icon_for(content_type)
    case content_type
    when /image/
      :image
    when /video/
      :video
    when /audio/
      :unmute
    when /pdf/
      :file
    when /zip|rar|tar|gz/
      :"file-zip"
    when /text|json|xml/
      :code
    else
      :file
    end
  end
end
