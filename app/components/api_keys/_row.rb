# frozen_string_literal: true

class Components::APIKeys::Row < Components::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(api_key:, index: 0)
    @api_key = api_key
    @index = index
  end

  def view_template
    div(
      style: "padding: 16px; #{index > 0 ? 'border-top: 1px solid var(--borderColor-default, #d0d7de);' : ''}",
      data: { api_key_id: api_key.id }
    ) do
      div(style: "display: flex; justify-content: space-between; align-items: flex-start; gap: 16px;") do
        div(style: "flex: 1; min-width: 0;") do
          div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;") do
            render Primer::Beta::Octicon.new(icon: :key, size: :small)
            div(style: "font-size: 14px; font-weight: 500;") do
              plain api_key.name
            end
          end
          div(style: "font-size: 12px; color: var(--fgColor-muted, #656d76); font-family: monospace;") do
            plain api_key.masked_token
          end
          div(style: "font-size: 12px; color: var(--fgColor-muted, #656d76); margin-top: 4px;") do
            plain "Created #{time_ago_in_words(api_key.created_at)} ago"
          end
        end

        render_revoke_dialog
      end
    end
  end

  private

  attr_reader :api_key, :index

  def render_revoke_dialog
    render Primer::Alpha::Dialog.new(title: "Revoke API key?", size: :medium) do |dialog|
      dialog.with_show_button(scheme: :danger, size: :small) do
        render Primer::Beta::Octicon.new(icon: :trash)
      end
      dialog.with_header(variant: :large) do
        h1(style: "margin: 0;") { "Revoke \"#{api_key.name}\"?" }
      end
      dialog.with_body do
        p(style: "margin: 0;") do
          plain "This action cannot be undone. Any applications using this API key will immediately lose access."
        end
      end
      dialog.with_footer do
        div(style: "display: flex; justify-content: flex-end; gap: 8px;") do
          form_with url: api_key_path(api_key), method: :delete, style: "display: inline;" do
            button(type: "submit", class: "btn btn-danger") do
              plain "Revoke key"
            end
          end
        end
      end
    end
  end
end
