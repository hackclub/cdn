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
    div(class: "d-flex flex-justify-between flex-items-#{compact ? 'center' : 'start'} gap-3") do
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
    div(class: "flex-1 min-width-0") do
      div(class: "f5 text-bold text-truncate") do
        render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small, mr: 1)
        plain upload.filename.to_s
      end
      div(class: "f6 color-fg-muted mt-1") do
        plain "#{upload.human_file_size} • #{time_ago_in_words(upload.created_at)} ago"
      end
    end

    div(class: "d-flex gap-2 flex-items-center") do
      render Primer::Beta::Button.new(
        href: upload.cdn_url,
        tag: :a,
        size: :small,
        target: "_blank",
        rel: "noopener"
      ) { "View" }

      render_delete_dialog
    end
  end

  def full_content
    div(class: "flex-1 min-width-0") do
      div(class: "d-flex flex-items-center gap-2 mb-1") do
        render Primer::Beta::Octicon.new(icon: file_icon_for(upload.content_type), size: :small)
        span(class: "f5 text-bold text-truncate") { upload.filename.to_s }
        render Primer::Beta::Label.new(scheme: :secondary, size: :small) { upload.provenance.titleize }
      end
      div(class: "f6 color-fg-muted") do
        plain "#{upload.human_file_size} • #{upload.content_type} • #{time_ago_in_words(upload.created_at)} ago"
      end
    end

    div(class: "d-flex gap-2 flex-items-center") do
      render Primer::Beta::Button.new(
        href: upload.cdn_url,
        tag: :a,
        size: :small,
        target: "_blank",
        rel: "noopener"
      ) do |button|
        button.with_leading_visual_icon(icon: :link)
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
        h1(class: "h3") { "Delete #{upload.filename}?" }
      end
      dialog.with_body do
        p(class: "color-fg-muted") do
          plain "This action cannot be undone. The file will be permanently removed from the CDN."
        end
      end
      dialog.with_footer do
        div(class: "d-flex flex-justify-end gap-2") do
          form_with url: (admin ? admin_upload_path(upload) : upload_path(upload)), method: :delete, class: "d-inline" do
            render Primer::Beta::Button.new(type: :submit, scheme: :danger) { "Delete" }
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
