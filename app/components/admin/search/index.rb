# frozen_string_literal: true

class Components::Admin::Search::Index < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  def initialize(query: nil, users: [], uploads: [], type: "all")
    @query = query
    @users = users
    @uploads = uploads
    @type = type
  end

  def view_template
    div(class: "container-lg p-4") do
      header_section
      tabs_section
      search_form
      results_section if @query.present?
    end
  end

  private

  def header_section
    div(class: "mb-4") do
      h1(class: "h2 mb-1") { "Admin Search" }
      p(class: "color-fg-muted f5") do
        "Search users and uploads by ID, email, filename, URL, etc."
      end
    end
  end

  def tabs_section
    render Primer::Alpha::UnderlineNav.new(label: "Search type") do |nav|
      nav.with_tab(selected: @type == "all", href: admin_search_path(type: "all", q: @query)) { "All" }
      nav.with_tab(selected: @type == "users", href: admin_search_path(type: "users", q: @query)) { "Users" }
      nav.with_tab(selected: @type == "uploads", href: admin_search_path(type: "uploads", q: @query)) { "Uploads" }
    end
  end

  def search_form
    div(class: "mb-4 mt-3") do
      form_with url: admin_search_path, method: :get, class: "d-flex gap-2" do
        input(type: "hidden", name: "type", value: @type)
        input(
          type: "search",
          name: "q",
          placeholder: search_placeholder,
          value: @query,
          class: "form-control flex-1",
          style: "max-width: 600px;",
          autofocus: true
        )
        render Primer::Beta::Button.new(type: :submit, scheme: :primary) do |button|
          button.with_leading_visual_icon(icon: :search)
          plain "Search"
        end
      end
    end
  end

  def search_placeholder
    case @type
    when "users" then "Search by ID, email, name, slack_id..."
    when "uploads" then "Search by ID, filename, URL, uploader..."
    else "Search by ID, email, filename, URL..."
    end
  end

  def results_section
    if @users.empty? && @uploads.empty?
      empty_state
    else
      users_section if @users.any?
      uploads_section if @uploads.any?
    end
  end

  def users_section
    div(class: "mb-5") do
      h2(class: "h4 mb-3") do
        plain "Users "
        render Primer::Beta::Label.new(scheme: :secondary) { @users.size.to_s }
      end
      render Primer::Beta::BorderBox.new do |box|
        @users.each do |user|
          box.with_row do
            user_row(user)
          end
        end
      end
    end
  end

  def user_row(user)
    div(class: "d-flex flex-justify-between flex-items-center") do
      div do
        div(class: "text-bold") { user.name || "Unnamed" }
        div(class: "f6 color-fg-muted") do
          plain user.email
          plain " · "
          code(class: "f6") { user.public_id }
        end
      end
      div(class: "d-flex flex-items-center gap-3") do
        div(class: "text-right f6 color-fg-muted") do
          div { "#{user.total_files} files" }
          div { user.total_storage_formatted }
        end
        if user.is_admin?
          render Primer::Beta::Label.new(scheme: :accent) { "ADMIN" }
        end
        div(class: "d-flex gap-2") do
          render Primer::Beta::IconButton.new(
            icon: :eye,
            "aria-label": "View user",
            href: admin_user_path(user),
            tag: :a,
            size: :small
          )
          button_to admin_user_path(user), method: :delete, class: "d-inline", data: { turbo_confirm: "Delete user #{user.name || user.email} and all their uploads?" } do
            render Primer::Beta::IconButton.new(
              icon: :trash,
              "aria-label": "Delete user",
              scheme: :danger,
              size: :small,
              tag: :span
            )
          end
        end
      end
    end
  end

  def uploads_section
    div do
      h2(class: "h4 mb-3") do
        plain "Uploads "
        render Primer::Beta::Label.new(scheme: :secondary) { @uploads.size.to_s }
      end
      render Primer::Beta::BorderBox.new do |box|
        @uploads.each do |upload|
          box.with_row do
            render Components::Uploads::Row.new(upload: upload, compact: true, admin: true)
          end
        end
      end
    end
  end

  def empty_state
    render Primer::Beta::Blankslate.new(border: true) do |component|
      component.with_visual_icon(icon: :search)
      component.with_heading(tag: :h2) { "No results found" }
      component.with_description { "Try a different search query" }
    end
  end
end
