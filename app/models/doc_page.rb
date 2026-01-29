# frozen_string_literal: true

class DocPage
  DOCS_PATH = Rails.root.join("app/views/docs/pages")

  attr_reader :id, :title, :icon, :order, :content

  def initialize(id:, title:, icon:, order:, content:)
    @id = id
    @title = title
    @icon = icon
    @order = order
    @content = content
  end

  class << self
    def all
      @all ||= load_all_docs.sort_by(&:order)
    end

    def find(id)
      all.find { |doc| doc.id == id } || raise(ActiveRecord::RecordNotFound, "Doc '#{id}' not found")
    end

    def reload!
      @all = nil
    end

    private

    def load_all_docs
      Dir.glob(DOCS_PATH.join("*.md")).map do |file|
        parse_doc_file(file)
      end
    end

    def parse_doc_file(file)
      id = File.basename(file, ".md")
      raw_content = File.read(file)
      frontmatter, content = extract_frontmatter(raw_content)

      new(
        id: id,
        title: frontmatter["title"] || id.titleize,
        icon: (frontmatter["icon"] || "file").to_sym,
        order: frontmatter["order"] || 999,
        content: render_markdown(content)
      )
    end

    def extract_frontmatter(content)
      if content.start_with?("---")
        parts = content.split("---", 3)
        if parts.length >= 3
          frontmatter = YAML.safe_load(parts[1]) || {}
          return [frontmatter, parts[2].strip]
        end
      end
      [{}, content]
    end

    def render_markdown(content)
      renderer = Redcarpet::Render::HTML.new(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener" }
      )
      markdown = Redcarpet::Markdown.new(
        renderer,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        highlight: true,
        footnotes: true
      )
      markdown.render(content)
    end
  end
end
