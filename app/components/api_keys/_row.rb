# frozen_string_literal: true

class Components::APIKeys::Row < Components::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(api_key:)
    @api_key = api_key
  end

  def view_template
    div(class: "d-flex flex-justify-between flex-items-start gap-3") do
      div(class: "flex-1 min-width-0") do
        div(class: "d-flex flex-items-center gap-2 mb-1") do
          render Primer::Beta::Octicon.new(icon: :key, size: :small, color: :muted)
          span(class: "f5 text-bold") { api_key.name }
        end
        code(class: "f6 color-fg-muted") { api_key.masked_token }
        div(class: "f6 color-fg-muted mt-1") do
          plain "Created #{time_ago_in_words(api_key.created_at)} ago"
        end
      end

      render_revoke_dialog
    end
  end

  private

  attr_reader :api_key

  def render_revoke_dialog
    render Primer::Alpha::Dialog.new(title: "Revoke API key?", size: :medium) do |dialog|
      dialog.with_show_button(scheme: :danger, size: :small) do
        render Primer::Beta::Octicon.new(icon: :trash)
      end
      dialog.with_header(variant: :large) do
        h1(class: "h3") { "Revoke \"#{api_key.name}\"?" }
      end
      dialog.with_body do
        p(class: "color-fg-muted") do
          plain "This action cannot be undone. Any applications using this API key will immediately lose access."
        end
      end
      dialog.with_footer do
        div(class: "d-flex flex-justify-end gap-2") do
          form_with url: api_key_path(api_key), method: :delete, class: "d-inline" do
            render Primer::Beta::Button.new(type: :submit, scheme: :danger) { "Revoke key" }
          end
        end
      end
    end
  end
end
