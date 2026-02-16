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
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      tabs_section
      search_form
      results_section if @query.present?
    end
  end

  private

  def header_section
    header(style: "margin-bottom: 24px;") do
      h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { "Admin Search" }
      p(style: "color: var(--fgColor-muted, #656d76); margin: 8px 0 0; font-size: 14px;") do
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
    div(style: "margin-bottom: 24px; margin-top: 16px;") do
      form_with url: admin_search_path, method: :get, style: "display: flex; gap: 8px;" do
        input(type: "hidden", name: "type", value: @type)
        input(
          type: "search",
          name: "q",
          placeholder: search_placeholder,
          value: @query,
          class: "form-control",
          style: "flex: 1; max-width: 600px;",
          autofocus: true
        )
        button(type: "submit", class: "btn btn-primary") do
          render Primer::Beta::Octicon.new(icon: :search, mr: 1)
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
    div(style: "margin-bottom: 32px;") do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") do
        plain "Users "
        render(Primer::Beta::Label.new(scheme: :secondary)) { plain @users.size.to_s }
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
    div(style: "display: flex; justify-content: space-between; align-items: center;") do
      div do
        div(style: "font-weight: 500;") { user.name || "Unnamed" }
        div(style: "font-size: 12px; color: var(--fgColor-muted);") do
          plain user.email
          plain " · "
          code(style: "font-size: 11px;") { user.public_id }
        end
      end
      div(style: "display: flex; align-items: center; gap: 16px;") do
        div(style: "text-align: right; font-size: 12px; color: var(--fgColor-muted);") do
          div { pluralize(user.total_files, "file") }
          div { user.total_storage_formatted }
        end
        if user.is_admin?
          render(Primer::Beta::Label.new(scheme: :accent)) { plain "ADMIN" }
        end
        link_to admin_user_path(user), class: "btn btn-sm", title: "View user" do
          render Primer::Beta::Octicon.new(icon: :eye, size: :small)
        end
      end
    end
  end

  def uploads_section
    div do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") do
        plain "Uploads "
        render(Primer::Beta::Label.new(scheme: :secondary)) { plain @uploads.size.to_s }
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
