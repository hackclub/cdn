# frozen_string_literal: true

class Components::Docs::Content < Components::Base
  def initialize(doc:)
    @doc = doc
  end

  def view_template
    style do
      raw(<<~CSS.html_safe)
        .markdown-body h1 { font-size: 2em; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid var(--borderColor-default); }
        .markdown-body h2 { font-size: 1.5em; margin-top: 24px; margin-bottom: 16px; }
        .markdown-body h3 { font-size: 1.25em; margin-top: 24px; margin-bottom: 16px; }
        .markdown-body p { margin-bottom: 16px; line-height: 1.6; }
        .markdown-body ul, .markdown-body ol { padding-left: 2em; margin-bottom: 16px; }
        .markdown-body li { margin-bottom: 4px; }
        .markdown-body code { background: var(--bgColor-muted); padding: 2px 6px; border-radius: 4px; font-size: 85%; }
        .markdown-body pre { background: var(--bgColor-muted); padding: 16px; border-radius: 6px; overflow-x: auto; margin-bottom: 16px; }
        .markdown-body pre code { background: none; padding: 0; }
        .markdown-body a { color: var(--fgColor-accent); }
        .markdown-body blockquote { padding: 0 1em; color: var(--fgColor-muted); border-left: 4px solid var(--borderColor-default); margin-bottom: 16px; }
        .markdown-body table { border-collapse: collapse; margin-bottom: 16px; width: 100%; }
        .markdown-body th, .markdown-body td { border: 1px solid var(--borderColor-default); padding: 8px 12px; }
        .markdown-body th { background: var(--bgColor-muted); }
      CSS
    end

    article(class: "markdown-body") do
      raw @doc.content.html_safe
    end
  end
end
