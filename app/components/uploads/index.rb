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

      link_to new_upload_path, class: "btn btn-primary" do
        render Primer::Beta::Octicon.new(icon: :upload, mr: 1)
        plain "Upload File"
      end
    end
  end

  def search_section
    div(style: "margin-bottom: 24px;") do
      form_with url: uploads_path, method: :get, style: "display: flex; gap: 8px;" do
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
      component.with_visual_icon(icon: :inbox)
      component.with_heading(tag: :h2) do
        query.present? ? "No files found" : "No uploads yet"
      end
      component.with_description do
        query.present? ? "Try a different search query" : "Upload your first file to get started"
      end
      unless query.present?
        component.with_primary_action(href: new_upload_path) do
          render Primer::Beta::Octicon.new(icon: :upload, mr: 1)
          plain "Upload File"
        end
      end
    end
  end

  def pagination_section
    div(style: "margin-top: 24px; text-align: center;") do
      paginate uploads
    end
  end
end
