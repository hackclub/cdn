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
      quota_section
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

  def quota_section
    quota_service = QuotaService.new(@user)
    usage = quota_service.current_usage
    policy = quota_service.current_policy

    div(style: "margin-bottom: 24px;") do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin-bottom: 12px;") { "Quota Management" }
      render Primer::Beta::BorderBox.new do |box|
        box.with_body(padding: :normal) do
          # Current policy
          div(style: "margin-bottom: 16px;") do
            div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;") do
              span(style: "font-weight: 500;") { "Current Policy:" }
              render(Primer::Beta::Label.new(scheme: quota_policy_scheme)) { policy.slug.to_s.humanize }
              if @user.quota_policy.present?
                render(Primer::Beta::Label.new(scheme: :accent)) { "Override" }
              end
            end
            div(style: "font-size: 12px; color: var(--fgColor-muted);") do
              plain "Per-file limit: #{helpers.number_to_human_size(policy.max_file_size)} · "
              plain "Total storage: #{helpers.number_to_human_size(policy.max_total_storage)}"
            end
          end

          # Usage stats
          div(style: "margin-bottom: 16px;") do
            div(style: "font-weight: 500; margin-bottom: 4px;") { "Storage Usage" }
            div(style: "font-size: 14px; margin-bottom: 4px;") do
              plain "#{helpers.number_to_human_size(usage[:storage_used])} / #{helpers.number_to_human_size(usage[:storage_limit])} "
              span(style: "color: var(--fgColor-muted);") { "(#{usage[:percentage_used]}%)" }
            end
            # Progress bar
            div(style: "background: var(--bgColor-muted); border-radius: 3px; height: 8px; overflow: hidden;") do
              div(style: "background: #{progress_bar_color(usage[:percentage_used])}; height: 100%; width: #{[ usage[:percentage_used], 100 ].min}%;")
            end
          end

          # Admin controls
          form(action: helpers.admin_user_path(@user), method: :post, style: "display: flex; gap: 8px; align-items: center;") do
            input(type: "hidden", name: "_method", value: "patch")
            input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)

            render(Primer::Alpha::SelectPanel.new(
              select_variant: :single,
              fetch_strategy: :local,
              dynamic_label: true,
              dynamic_label_prefix: "Quota Policy",
              form_arguments: { name: "user[quota_policy]" }
            )) do |panel|
              panel.with_show_button(scheme: :secondary, size: :small) { current_quota_label }
              panel.with_item(label: "Auto-detect (via HCA)", content_arguments: { data: { value: "" } }, active: @user.quota_policy.nil?)
              panel.with_item(label: "Verified", content_arguments: { data: { value: "verified" } }, active: @user.quota_policy == "verified")
              panel.with_item(label: "Functionally Unlimited", content_arguments: { data: { value: "functionally_unlimited" } }, active: @user.quota_policy == "functionally_unlimited")
            end

            button(type: "submit", class: "btn btn-sm btn-primary") { "Set Policy" }
          end
        end
      end
    end
  end

  def quota_policy_scheme
    case @user.quota_policy&.to_sym
    when :functionally_unlimited
      :success
    when :verified
      :accent
    else
      :default
    end
  end

  def current_quota_label
    case @user.quota_policy&.to_sym
    when :functionally_unlimited
      "Functionally Unlimited"
    when :verified
      "Verified"
    else
      "Auto-detect (via HCA)"
    end
  end

  def progress_bar_color(percentage)
    if percentage >= 100
      "var(--bgColor-danger-emphasis)"
    elsif percentage >= 80
      "var(--bgColor-attention-emphasis)"
    else
      "var(--bgColor-success-emphasis)"
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
