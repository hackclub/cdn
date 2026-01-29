# frozen_string_literal: true

class Components::HeaderBar < Components::Base
  register_value_helper :signed_in?
  register_value_helper :impersonating?

  def view_template
    header(class: "app-header", style: "display: flex; align-items: center; justify-content: space-between;") do
      div(style: "display: flex; align-items: center; gap: 1rem;") do
        span(class: "app-header-brand") do
          plain "Hack Club CDN"
          sup(class: "app-header-env-badge") { "(dev)" } if Rails.env.development?
        end
      end

      return unless signed_in?
      div(style: "display: flex; align-items: center; gap: 0.5rem;") do

        render(Primer::Alpha::ActionMenu.new(anchor_align: :end)) do |menu|
          menu.with_show_button(scheme: :invisible) do |btn|
            btn.with_leading_visual_icon(icon: impersonating? ? :eye : :person)
            plain current_user.name
          end

          menu.with_item(label: "Log out", href: logout_path, form_arguments: { method: :delete }) do |item|
            item.with_leading_visual_icon(icon: :"sign-out")
          end
        end
      end
    end
  end
end
