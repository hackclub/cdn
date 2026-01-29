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
          h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { @user.name || "Unnamed User" }
          p(style: "color: var(--fgColor-muted, #656d76); margin: 8px 0 0; font-size: 14px;") do
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
        div(style: "display: flex; gap: 8px;") do
          if @user.is_admin?
            span(style: "background: #8250df; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px;") { "ADMIN" }
          end
          link_to admin_search_path, class: "btn" do
            plain "Back to Search"
          end
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
    div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; padding: 16px;") do
      div(style: "font-size: 12px; color: var(--fgColor-muted);") { label }
      div(style: "font-size: 24px; font-weight: 600; margin-top: 4px;") { value }
    end
  end

  def api_keys_section
    api_keys = @user.api_keys.recent
    return if api_keys.empty?

    div(style: "margin-bottom: 24px;") do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") { "API Keys" }
      div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
        api_keys.each do |api_key|
          api_key_row(api_key)
        end
      end
    end
  end

  def api_key_row(api_key)
    div(style: "display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--borderColor-default, #d0d7de);") do
      div do
        div(style: "font-weight: 500;") { api_key.name }
        code(style: "font-size: 12px; color: var(--fgColor-muted);") { api_key.masked_token }
      end
      div(style: "display: flex; align-items: center; gap: 12px;") do
        if api_key.revoked?
          span(style: "background: #cf222e; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;") { "REVOKED" }
        else
          span(style: "background: #1a7f37; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;") { "ACTIVE" }
          button_to "Revoke", helpers.admin_api_key_path(api_key), method: :delete, class: "btn btn-sm btn-danger", data: { confirm: "Revoke this API key?" }
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
      div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
        uploads.each do |upload|
          upload_row(upload)
        end
      end
    end
  end

  def upload_row(upload)
    render Components::Uploads::Row.new(upload: upload, compact: true, admin: true)
  end
end
