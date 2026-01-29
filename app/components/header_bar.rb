# frozen_string_literal: true

class Components::HeaderBar < Components::Base
  register_value_helper :signed_in?
  register_value_helper :impersonating?

  def view_template
    header(class: "app-header", style: "display: flex; align-items: center; justify-content: space-between;") do
      div(style: "display: flex; align-items: center; gap: 1rem;") do
        a(href: root_path, class: "app-header-brand", style: "text-decoration: none; color: inherit;") do
          plain "Hack Club CDN"
          sup(class: "app-header-env-badge") { "(dev)" } if Rails.env.development?
        end
        nav(style: "display: flex; align-items: center; gap: 1rem; margin-left: 1rem;") do
          if signed_in?
            a(href: uploads_path, style: "color: var(--fgColor-default); text-decoration: none; font-size: 14px;") { "Uploads" }
          end
          a(href: doc_path("getting-started"), style: "color: var(--fgColor-default); text-decoration: none; font-size: 14px;") { "Docs" }
          admin_tool(element: "span") do
            a(href: admin_search_path, style: "color: var(--fgColor-default); text-decoration: none; font-size: 14px;") { "Search" }
          end
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
