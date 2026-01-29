# frozen_string_literal: true

class Components::Uploads::New < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      upload_form
    end
  end

  private

  def header_section
    header(style: "margin-bottom: 32px;") do
      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 16px;") do
        link_to uploads_path, style: "color: var(--fgColor-muted, #656d76); text-decoration: none;" do
          render Primer::Beta::Octicon.new(icon: :"arrow-left")
        end
        h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { "Upload File" }
      end
      p(style: "color: var(--fgColor-muted, #656d76); margin: 0; font-size: 14px;") do
        plain "Drop a file anywhere on this page or click to browse"
      end
    end
  end

  def upload_form
    form_with url: uploads_path, method: :post, multipart: true, data: { dropzone_form: true } do
      # Main upload area - drag anywhere on page for full-screen overlay
      div(
        class: "upload-area",
        style: upload_area_styles
      ) do
        div(style: "text-align: center;") do
          render Primer::Beta::Octicon.new(icon: :upload, size: :medium)
          h2(style: "font-size: 32px; font-weight: 600; margin: 24px 0 16px;") { "Drag & Drop" }
          p(style: "color: var(--fgColor-muted, #656d76); margin: 0 0 32px; font-size: 16px;") do
            plain "Drop a file anywhere on this page to upload instantly"
          end

          label(
            for: "file-input",
            class: "btn btn-primary btn-large",
            style: "cursor: pointer; display: inline-block; font-size: 16px; padding: 12px 24px;"
          ) do
            render Primer::Beta::Octicon.new(icon: :file, mr: 2)
            plain "Choose File"
          end

          input(
            type: "file",
            name: "file",
            id: "file-input",
            data: { dropzone_input: true },
            style: "display: none;"
          )
        end
      end

      # Tips section
      div(style: "margin-top: 48px; padding: 24px; background: var(--bgColor-muted, #f6f8fa); border-radius: 8px;") do
        h3(style: "font-size: 16px; font-weight: 600; margin: 0 0 16px;") { "How it works" }
        ul(style: "margin: 0; padding-left: 24px; font-size: 14px; color: var(--fgColor-muted, #656d76); line-height: 1.8;") do
          li { "Drag and drop a file anywhere on this page for instant upload" }
          li { "Or click the button above to browse and select a file" }
          li { "Files are stored securely and accessible via CDN URLs" }
          li { "Supports images, videos, documents, and more" }
        end
      end
    end
  end

  def upload_area_styles
    <<~CSS.strip
      border: 3px dashed var(--borderColor-default, #d0d7de);
      border-radius: 16px;
      padding: 96px 48px;
      background: var(--bgColor-default, #fff);
      text-align: center;
      transition: all 0.2s ease;
    CSS
  end
end
