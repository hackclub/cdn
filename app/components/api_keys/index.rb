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
    div(
      style: "background: var(--bgColor-success-muted, #dafbe1); border: 1px solid var(--borderColor-success-emphasis, #1a7f37); border-radius: 6px; padding: 16px; margin-bottom: 24px;"
    ) do
      div(style: "display: flex; align-items: flex-start; gap: 12px;") do
        render Primer::Beta::Octicon.new(icon: :check, size: :medium, color: :success)
        div(style: "flex: 1;") do
          p(style: "margin: 0 0 8px; font-weight: 600; color: var(--fgColor-success, #1a7f37);") do
            plain "API key created successfully!"
          end
          p(style: "margin: 0 0 8px; color: var(--fgColor-default, #1f2328); font-size: 14px;") do
            plain "Copy your API key now. You won't be able to see it again!"
          end
          div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; padding: 12px; font-family: monospace; font-size: 14px; word-break: break-all;") do
            plain new_token
          end
        end
      end
    end
  end

  def create_form
    div(style: "background: linear-gradient(135deg, var(--bgColor-default, #fff) 0%, var(--bgColor-muted, #f6f8fa) 100%); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 12px; overflow: hidden; margin-bottom: 24px;") do
      # Header with icon
      div(style: "padding: 20px 24px; border-bottom: 1px solid var(--borderColor-muted, #d0d7de); display: flex; align-items: center; gap: 12px;") do
        div(style: "width: 40px; height: 40px; border-radius: 10px; background: linear-gradient(135deg, #0969da 0%, #0550ae 100%); display: flex; align-items: center; justify-content: center; color: #fff;") do
          render Primer::Beta::Octicon.new(icon: :key, size: :small)
        end
        div do
          h2(style: "font-size: 1.125rem; font-weight: 600; margin: 0; color: var(--fgColor-default, #1f2328);") { "Create new API key" }
          p(style: "font-size: 13px; color: var(--fgColor-muted, #656d76); margin: 2px 0 0;") { "Generate a key to access the CDN API programmatically" }
        end
      end

      # Form body
      div(style: "padding: 24px;") do
        form_with url: api_keys_path, method: :post do
          div(style: "margin-bottom: 20px;") do
            label(for: "api_key_name", style: "display: block; font-size: 14px; font-weight: 600; margin-bottom: 8px; color: var(--fgColor-default, #1f2328);") do
              plain "Key name"
            end
            p(style: "font-size: 12px; color: var(--fgColor-muted, #656d76); margin: 0 0 8px;") do
              plain "Give your key a memorable name so you can identify it later"
            end
            input(
              type: "text",
              name: "api_key[name]",
              id: "api_key_name",
              placeholder: "e.g., Production server, CI/CD pipeline, Local dev",
              required: true,
              class: "form-control",
              style: "max-width: 400px; padding: 10px 12px; font-size: 14px;"
            )
          end

          button(type: "submit", class: "btn btn-primary", style: "padding: 10px 20px; font-size: 14px; font-weight: 600;") do
            render Primer::Beta::Octicon.new(icon: :plus, mr: 2)
            plain "Generate API key"
          end
        end
      end
    end
  end

  def api_keys_list
    div do
      h2(style: "font-size: 1.25rem; font-weight: 600; margin: 0 0 16px;") { "Your API keys" }

      if api_keys.any?
        div(style: "background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px; overflow: hidden;") do
          api_keys.each_with_index do |api_key, index|
            render Components::APIKeys::Row.new(api_key: api_key, index: index)
          end
        end
      else
        empty_state
      end
    end
  end

  def empty_state
    div(style: "text-align: center; padding: 64px 24px; color: var(--fgColor-muted, #656d76); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 6px;") do
      render Primer::Beta::Octicon.new(icon: :key, size: :medium)
      h3(style: "font-size: 20px; font-weight: 600; margin: 16px 0 8px;") { "No API keys yet" }
      p(style: "margin: 0;") { "Create your first API key to get started with the API" }
    end
  end
end
