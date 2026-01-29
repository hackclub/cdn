# frozen_string_literal: true

class Components::APIKeys::Index < Components::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(api_keys:, new_token: nil)
    @api_keys = api_keys
    @new_token = new_token
  end

  def view_template
    div(class: "container-lg p-4") do
      header_section
      new_token_alert if new_token
      create_form
      api_keys_list
    end
  end

  private

  attr_reader :api_keys, :new_token

  def header_section
    div(class: "mb-4") do
      h1(class: "h2 mb-1") { "API Keys" }
      p(class: "color-fg-muted f5") do
        plain "Manage your API keys for programmatic access. "
        a(href: "/docs/api", class: "Link") { "View API documentation" }
      end
    end
  end

  def new_token_alert
    render Primer::Beta::Flash.new(scheme: :success, mb: 4) do |component|
      component.with_icon(icon: :check)
      div do
        p(class: "text-bold mb-1") { "API key created successfully!" }
        p(class: "mb-2") { "Copy your API key now. You won't be able to see it again!" }
        code(class: "d-block p-2 color-bg-subtle rounded-2 f5 text-mono") { new_token }
      end
    end
  end

  def create_form
    render Primer::Beta::BorderBox.new(mb: 4) do |box|
      box.with_header do
        h2(class: "f5 text-bold") { "Create new API key" }
      end
      box.with_body do
        form_with url: api_keys_path, method: :post do
          div(class: "mb-3", style: "max-width: 400px;") do
            label(for: "api_key_name", class: "f5 text-bold d-block mb-2") { "Key name" }
            input(
              type: "text",
              name: "api_key[name]",
              id: "api_key_name",
              placeholder: "e.g., The Coolest App That's Ever Lived",
              required: true,
              class: "form-control width-full"
            )
          end
          render Primer::Beta::Button.new(type: :submit, scheme: :primary) do |button|
            button.with_leading_visual_icon(icon: :key)
            plain "Create key"
          end
        end
      end
    end
  end

  def api_keys_list
    div do
      h2(class: "h4 mb-3") { "Your API keys" }

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
