# frozen_string_literal: true

class Components::Uploads::New < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    div(class: "container-lg p-4") do
      header_section
      upload_form
    end
  end

  private

  def header_section
    div(class: "mb-4") do
      div(class: "d-flex flex-items-center gap-2 mb-2") do
        render Primer::Beta::Button.new(href: uploads_path, tag: :a, scheme: :invisible, size: :small) do
          render Primer::Beta::Octicon.new(icon: :"arrow-left")
        end
        h1(class: "h2 mb-0") { "Upload File" }
      end
      p(class: "color-fg-muted f5 mb-0") do
        plain "Drop a file anywhere on this page or click to browse"
      end
    end
  end

  def upload_form
    form_with url: uploads_path, method: :post, multipart: true, data: { dropzone_form: true } do
      div(
        class: "upload-area rounded-3 p-6 text-center",
        style: "border: 3px dashed var(--borderColor-default); transition: all 0.2s ease;"
      ) do
        div(class: "py-6") do
          render Primer::Beta::Octicon.new(icon: :upload, size: :medium, color: :muted)
          h2(class: "h1 mt-4 mb-3") { "Drag & Drop" }
          p(class: "color-fg-muted f4 mb-4") do
            plain "Drop a file anywhere on this page to upload instantly"
          end

          label(
            for: "file-input",
            class: "btn btn-primary btn-large",
            style: "cursor: pointer;"
          ) do
            render Primer::Beta::Octicon.new(icon: :file, mr: 2)
            plain "Choose File"
          end

          input(
            type: "file",
            name: "file",
            id: "file-input",
            data: { dropzone_input: true },
            class: "d-none"
          )
        end
      end

      render Primer::Beta::BorderBox.new(mt: 5) do |box|
        box.with_header do
          h3(class: "f5 text-bold") { "How it works" }
        end
        box.with_body do
          ul(class: "color-fg-muted f5 pl-4 mb-0", style: "line-height: 1.8;") do
            li { "Drag and drop a file anywhere on this page for instant upload" }
            li { "Or click the button above to browse and select a file" }
            li { "Files are stored securely and accessible via CDN URLs" }
            li { "Supports images, videos, documents, and more" }
          end
        end
      end
    end
  end
end
