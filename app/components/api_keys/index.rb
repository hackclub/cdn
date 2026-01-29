# frozen_string_literal: true

class Components::APIKeys::Index < Components::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(api_keys:, new_token: nil)
    @api_keys = api_keys
    @new_token = new_token
  end

  def view_template
    div(style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      new_token_alert if new_token
      create_form
      api_keys_list
    end
  end

  private

  attr_reader :api_keys, :new_token

  def header_section
    header(style: "margin-bottom: 24px;") do
      h1(style: "font-size: 2rem; font-weight: 600; margin: 0;") { "API Keys" }
      p(style: "color: var(--fgColor-muted, #656d76); margin: 8px 0 0; font-size: 14px;") do
        plain "Manage your API keys for programmatic access. "
        a(href: "/docs/api", style: "color: var(--fgColor-accent, #0969da);") { "View API documentation" }
      end
    end
  end

  def new_token_alert
    render Primer::Beta::Flash.new(scheme: :success, mb: 4) do |component|
      component.with_icon(icon: :check)
      div do
        p(style: "margin: 0 0 8px; font-weight: 600;") { "API key created successfully!" }
        p(style: "margin: 0 0 8px;") { "Copy your API key now. You won't be able to see it again!" }
        code(style: "display: block; padding: 12px; background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default); border-radius: 6px; font-size: 14px; word-break: break-all;") do
          plain new_token
        end
      end
    end
  end

  def create_form
    render Primer::Beta::BorderBox.new(mb: 4) do |box|
      box.with_header do
        h2(style: "font-size: 14px; font-weight: 600; margin: 0;") { "Create new API key" }
      end
      box.with_body do
        form_with url: api_keys_path, method: :post do
          div(style: "margin-bottom: 12px; max-width: 400px;") do
            label(for: "api_key_name", style: "display: block; font-size: 14px; font-weight: 600; margin-bottom: 8px;") do
              plain "Key name"
            end
            input(
              type: "text",
              name: "api_key[name]",
              id: "api_key_name",
              placeholder: "e.g., My App",
              required: true,
              class: "form-control"
            )
          end
          button(type: "submit", class: "btn btn-primary") do
            render Primer::Beta::Octicon.new(icon: :key, mr: 1)
            plain "Create key"
          end
        end
      end
    end
  end

  def api_keys_list
    div do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin: 0 0 16px;") { "Your API keys" }

      if api_keys.any?
        render Primer::Beta::BorderBox.new do |box|
          api_keys.each do |api_key|
            box.with_row do
              render Components::APIKeys::Row.new(api_key: api_key)
            end
          end
        end
      else
        empty_state
      end
    end
  end

  def empty_state
    render Primer::Beta::Blankslate.new(border: true) do |component|
      component.with_visual_icon(icon: :key)
      component.with_heading(tag: :h3) { "No API keys yet" }
      component.with_description { "Create your first API key to get started with the API" }
    end
  end
end
