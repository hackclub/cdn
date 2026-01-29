# frozen_string_literal: true

class Components::Admin::Users::Show < Components::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(user:)
    @user = user
  end

  def view_template
    div(style: "max-width: 800px; margin: 0 auto; padding: 24px;") do
      header_section
      stats_section
      api_keys_section
      uploads_section
    end
  end

  private

  def header_section
    header(style: "margin-bottom: 24px;") do
      div(style: "display: flex; justify-content: space-between; align-items: flex-start;") do
        div do
          div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;") do
            h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { @user.name || "Unnamed User" }
            if @user.is_admin?
              render(Primer::Beta::Label.new(scheme: :accent)) { plain "ADMIN" }
            end
          end
          p(style: "color: var(--fgColor-muted, #656d76); margin: 0; font-size: 14px;") do
            plain @user.email
            plain " · "
            code(style: "font-size: 12px;") { @user.public_id }
          end
          if @user.slack_id.present?
            p(style: "color: var(--fgColor-muted); margin: 4px 0 0; font-size: 12px;") do
              plain "Slack: "
              code { @user.slack_id }
            end
          end
        end
        link_to admin_search_path, class: "btn" do
          render Primer::Beta::Octicon.new(icon: :"arrow-left", mr: 1)
          plain "Back to Search"
        end
      end
    end
  end

  def stats_section
    div(style: "display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px;") do
      stat_card("Total Files", @user.total_files.to_s)
      stat_card("Total Storage", @user.total_storage_formatted)
      stat_card("Member Since", @user.created_at.strftime("%b %d, %Y"))
    end
  end

  def stat_card(label, value)
    render Primer::Beta::BorderBox.new do |box|
      box.with_body(padding: :normal) do
        div(style: "font-size: 12px; color: var(--fgColor-muted);") { label }
        div(style: "font-size: 24px; font-weight: 600; margin-top: 4px;") { value }
      end
    end
  end

  def api_keys_section
    api_keys = @user.api_keys.recent
    return if api_keys.empty?

    div(style: "margin-bottom: 24px;") do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") { "API Keys" }
      render Primer::Beta::BorderBox.new do |box|
        api_keys.each do |api_key|
          box.with_row do
            api_key_row(api_key)
          end
        end
      end
    end
  end

  def api_key_row(api_key)
    div(style: "display: flex; justify-content: space-between; align-items: center;") do
      div do
        div(style: "font-weight: 500;") { api_key.name }
        code(style: "font-size: 12px; color: var(--fgColor-muted);") { api_key.masked_token }
      end
      div(style: "display: flex; align-items: center; gap: 12px;") do
        if api_key.revoked?
          render(Primer::Beta::Label.new(scheme: :danger)) { plain "REVOKED" }
        else
          render(Primer::Beta::Label.new(scheme: :success)) { plain "ACTIVE" }
          button_to helpers.admin_api_key_path(api_key), method: :delete, class: "btn btn-sm btn-danger", data: { confirm: "Revoke this API key?" } do
            plain "Revoke"
          end
        end
        span(style: "font-size: 12px; color: var(--fgColor-muted);") { api_key.created_at.strftime("%b %d, %Y") }
      end
    end
  end

  def uploads_section
    uploads = @user.uploads.includes(:blob).order(created_at: :desc).limit(20)
    return if uploads.empty?

    div do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") { "Recent Uploads" }
      render Primer::Beta::BorderBox.new do |box|
        uploads.each do |upload|
          box.with_row do
            render Components::Uploads::Row.new(upload: upload, compact: true, admin: true)
          end
        end
      end
    end
  end
end
