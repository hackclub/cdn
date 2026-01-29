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
    div(class: "container-lg p-4") do
      header_section
      search_section
      uploads_list
      pagination_section if uploads.respond_to?(:total_pages) && uploads.total_pages > 1
    end
  end

  private

  attr_reader :uploads, :query

  def header_section
    div(class: "d-flex flex-justify-between flex-items-center mb-4") do
      div do
        h1(class: "h2 mb-1") { "Your Uploads" }
        p(class: "color-fg-muted f5 mb-0") do
          count = uploads.respond_to?(:total_count) ? uploads.total_count : uploads.size
          plain "#{count} file#{count == 1 ? '' : 's'}"
        end
      end

      render Primer::Beta::Button.new(href: new_upload_path, tag: :a, scheme: :primary) do |button|
        button.with_leading_visual_icon(icon: :upload)
        plain "Upload File"
      end
    end
  end

  def search_section
    div(class: "mb-4") do
      form_with url: uploads_path, method: :get, class: "d-flex gap-2" do
        input(
          type: "search",
          name: "query",
          placeholder: "Search files...",
          value: query,
          class: "form-control flex-1",
          style: "max-width: 400px;"
        )
        render Primer::Beta::Button.new(type: :submit) do |button|
          button.with_leading_visual_icon(icon: :search)
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
    div(class: "mt-4 text-center") do
      paginate uploads
    end
  end
end
