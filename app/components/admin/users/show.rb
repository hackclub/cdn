# frozen_string_literal: true

class Components::Admin::Users::Show < Components::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(user:)
    @user = user
  end

  def view_template
    div(class: "container-md p-4") do
      header_section
      stats_section
      api_keys_section
      uploads_section
    end
  end

  private

  def header_section
    div(class: "mb-4") do
      div(class: "d-flex flex-justify-between flex-items-start") do
        div do
          div(class: "d-flex flex-items-center gap-2 mb-1") do
            h1(class: "h2 mb-0") { @user.name || "Unnamed User" }
            if @user.is_admin?
              render Primer::Beta::Label.new(scheme: :accent) { "ADMIN" }
            end
          end
          div(class: "color-fg-muted f5") do
            plain @user.email
            plain " · "
            code(class: "f6") { @user.public_id }
          end
          if @user.slack_id.present?
            div(class: "color-fg-muted f6 mt-1") do
              plain "Slack: "
              code { @user.slack_id }
            end
          end
        end
        render Primer::Beta::Button.new(href: admin_search_path, tag: :a) do |button|
          button.with_leading_visual_icon(icon: :"arrow-left")
          plain "Back to Search"
        end
      end
    end
  end

  def stats_section
    div(class: "d-grid gap-3 mb-4", style: "grid-template-columns: repeat(3, 1fr);") do
      stat_card("Total Files", @user.total_files.to_s)
      stat_card("Total Storage", @user.total_storage_formatted)
      stat_card("Member Since", @user.created_at.strftime("%b %d, %Y"))
    end
  end

  def stat_card(label, value)
    render Primer::Beta::BorderBox.new do |box|
      box.with_body(padding: :normal) do
        div(class: "f6 color-fg-muted") { label }
        div(class: "h3 mt-1") { value }
      end
    end
  end

  def api_keys_section
    api_keys = @user.api_keys.recent
    return if api_keys.empty?

    div(class: "mb-4") do
      h2(class: "h4 mb-3") { "API Keys" }
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
    div(class: "d-flex flex-justify-between flex-items-center") do
      div do
        div(class: "text-bold") { api_key.name }
        code(class: "f6 color-fg-muted") { api_key.masked_token }
      end
      div(class: "d-flex flex-items-center gap-3") do
        if api_key.revoked?
          render Primer::Beta::Label.new(scheme: :danger) { "REVOKED" }
        else
          render Primer::Beta::Label.new(scheme: :success) { "ACTIVE" }
          button_to helpers.admin_api_key_path(api_key), method: :delete, class: "d-inline", data: { confirm: "Revoke this API key?" } do
            render Primer::Beta::Button.new(scheme: :danger, size: :small, tag: :span) { "Revoke" }
          end
        end
        span(class: "f6 color-fg-muted") { api_key.created_at.strftime("%b %d, %Y") }
      end
    end
  end

  def uploads_section
    uploads = @user.uploads.includes(:blob).order(created_at: :desc).limit(20)
    return if uploads.empty?

    div do
      h2(class: "h4 mb-3") { "Recent Uploads" }
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
