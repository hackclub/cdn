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
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      search_section
      uploads_list
      pagination_section if uploads.respond_to?(:total_pages) && uploads.total_pages > 1
    end
  end

  private

  attr_reader :uploads, :query

  def header_section
    header(style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;") do
      div do
        h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { "Your Uploads" }
        p(style: "color: var(--fgColor-muted, #656d76); margin: 8px 0 0; font-size: 14px;") do
          count = uploads.respond_to?(:total_count) ? uploads.total_count : uploads.size
          plain "#{count} file#{count == 1 ? '' : 's'}"
        end
      end

      label(for: "dropzone-file-input", class: "btn btn-primary", style: "cursor: pointer;") do
        render Primer::Beta::Octicon.new(icon: :upload, mr: 1)
        plain "Upload File"
      end
    end
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
    if uploads.any?
      render Primer::Beta::BorderBox.new do |box|
        uploads.each do |upload|
          box.with_row do
            render Components::Uploads::Row.new(upload: upload, compact: false)
          end
        end
      end
    else
      empty_state
    end
  end

  def empty_state
    render Primer::Beta::Blankslate.new(border: true) do |component|
      component.with_visual_icon(icon: query.present? ? :search : :upload, size: :medium)
      component.with_heading(tag: :h2) do
        query.present? ? "No files found" : "Drop files here"
      end
      component.with_description do
        if query.present?
          "Try a different search query"
        else
          "Drag and drop files anywhere on this page, or use the Upload button"
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
      input(type: "file", name: "file", id: "dropzone-file-input", data: { dropzone_input: true }, style: "display: none;")
    end
  end
end
