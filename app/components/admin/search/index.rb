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
    div(style: "display: flex; gap: 4px; margin-bottom: 16px; border-bottom: 1px solid var(--borderColor-default, #d0d7de);") do
      tab_link("All", "all")
      tab_link("Users", "users")
      tab_link("Uploads", "uploads")
    end
  end

  def tab_link(label, type)
    active = @type == type
    base_style = "padding: 8px 16px; text-decoration: none; border-bottom: 2px solid transparent; margin-bottom: -1px;"
    active_style = active ? "border-color: #0969da; color: #0969da; font-weight: 500;" : "color: var(--fgColor-muted);"

    link_to admin_search_path(type: type, q: @query), style: "#{base_style} #{active_style}" do
      plain label
    end
  end

  def search_form
    div(style: "margin-bottom: 24px;") do
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
        span(style: "color: var(--fgColor-muted); font-weight: normal;") { "(#{@users.size})" }
      end
      div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
        @users.each do |user|
          user_row(user)
        end
      end
    end
  end

  def user_row(user)
    div(style: "padding: 12px 16px; border-bottom: 1px solid var(--borderColor-default, #d0d7de); display: flex; justify-content: space-between; align-items: center;") do
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
          div { "#{user.total_files} files" }
          div { user.total_storage_formatted }
          if user.is_admin?
            span(style: "background: #8250df; color: white; padding: 2px 6px; border-radius: 4px; font-size: 10px; margin-left: 8px;") { "ADMIN" }
          end
        end
        div(style: "display: flex; gap: 8px;") do
          link_to admin_user_path(user), class: "btn btn-sm" do
            render Primer::Beta::Octicon.new(icon: :eye, size: :small)
          end
          button_to admin_user_path(user), method: :delete, class: "btn btn-sm btn-danger", data: { turbo_confirm: "Delete user #{user.name || user.email} and all their uploads?" } do
            render Primer::Beta::Octicon.new(icon: :trash, size: :small)
          end
        end
      end
    end
  end

  def uploads_section
    div do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") do
        plain "Uploads "
        span(style: "color: var(--fgColor-muted); font-weight: normal;") { "(#{@uploads.size})" }
      end
      div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
        @uploads.each do |upload|
          upload_row(upload)
        end
      end
    end
  end

  def upload_row(upload)
    render Components::Uploads::Row.new(upload: upload, compact: true, admin: true)
  end

  def empty_state
    div(style: "text-align: center; padding: 64px 24px; color: var(--fgColor-muted, #656d76);") do
      render Primer::Beta::Octicon.new(icon: :search, size: :medium)
      h2(style: "font-size: 20px; font-weight: 600; margin: 16px 0 8px;") { "No results found" }
      p(style: "margin: 0;") { "Try a different search query" }
    end
  end
end
