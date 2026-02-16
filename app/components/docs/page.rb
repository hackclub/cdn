# frozen_string_literal: true

class Components::Docs::Page < Components::Base
  def initialize(doc:, docs:)
    @doc = doc
    @docs = docs
  end

  def view_template
    div(class: "d-flex", style: "min-height: calc(100vh - 64px);") do
      render Components::Docs::Sidebar.new(docs: @docs, current_doc: @doc)
      main(class: "flex-auto p-4 p-md-5", style: "max-width: 900px;") do
        render Components::Docs::Content.new(doc: @doc)
      end
    end
  end
end
