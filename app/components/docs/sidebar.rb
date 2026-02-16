# frozen_string_literal: true

class Components::Docs::Sidebar < Components::Base
  def initialize(docs:, current_doc:)
    @docs = docs
    @current_doc = current_doc
  end

  def view_template
    aside(
      class: "color-bg-subtle border-right",
      style: "width: 280px; min-width: 280px; padding: 24px 16px;"
    ) do
      div(class: "mb-3") do
        a(href: root_path, class: "color-fg-muted text-small d-flex flex-items-center") do
          render Primer::Beta::Octicon.new(icon: "arrow-left", size: :small, mr: 1)
          plain "Back to CDN"
        end
      end

      h2(class: "h5 mb-3") { "Documentation" }

      render Primer::Beta::NavList.new(aria: { label: "Documentation" }) do |nav|
        @docs.each do |doc|
          nav.with_item(
            label: doc.title,
            href: doc_path(doc.id),
            selected: doc.id == @current_doc.id
          ) do |item|
            item.with_leading_visual_icon(icon: doc.icon)
          end
        end
      end
    end
  end
end
