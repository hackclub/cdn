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
    batch_delete_bar
  end

  private

  attr_reader :uploads, :query

  def header_section
    header(style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;") do
      div do
        h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { "Your Uploads" }
        p(style: "color: var(--fgColor-muted, #656d76); margin: 8px 0 0; font-size: 14px;") do
          count = uploads.respond_to?(:total_count) ? uploads.total_count : uploads.size
          plain pluralize(count, "file")
        end
      end

      label(for: "dropzone-file-input", class: "btn btn-primary", style: "cursor: pointer;") do
        render Primer::Beta::Octicon.new(icon: :upload, mr: 1)
        plain "Upload Files"
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
      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px; padding: 4px 0;") do
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

      render Primer::Beta::BorderBox.new do |box|
        uploads.each do |upload|
          box.with_row do
            div(style: "display: flex; align-items: flex-start; gap: 12px;") do
              input(
                type: "checkbox",
                name: "ids[]",
                value: upload.id,
                form: "batch-delete-form",
                data: { batch_select_item: true, upload_id: upload.id },
                style: "margin-top: 6px; cursor: pointer;"
              )
              div(style: "flex: 1; min-width: 0;") do
                render Components::Uploads::Row.new(upload: upload, compact: false)
              end
            end
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
          "Drag and drop files anywhere on this page, or use the Upload button (up to 40 files at once)"
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
          button(type: "submit", class: "btn btn-sm btn-danger", style: "white-space: nowrap;") do
            render Primer::Beta::Octicon.new(icon: :trash, mr: 1)
            plain "Delete"
          end
        end
      end
    end
  end
end
