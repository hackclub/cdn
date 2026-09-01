# frozen_string_literal: true

require "test_helper"

class DocPageTest < ActiveSupport::TestCase
  test "every doc page has a summary for /llms.txt to link with" do
    DocPage.all.each do |doc|
      assert doc.summary.present?,
        "#{doc.id}.md needs a `summary:` in its frontmatter (it becomes the /llms.txt link description)"
      refute_includes doc.summary, "\n"
    end
  end

  test "exposes the path it is served at" do
    doc = DocPage.find("api")

    assert_equal "/docs/api", doc.path
  end

  test "records the source file's last modification time" do
    doc = DocPage.find("api")

    assert_kind_of Time, doc.updated_at
    assert_equal File.mtime(DocPage::DOCS_PATH.join("api.md")).to_i, doc.updated_at.to_i
  end

  test "frontmatter is stripped from the rendered content" do
    doc = DocPage.find("api")

    refute_includes doc.content, "summary:"
    refute_includes doc.content, "order:"
  end
end
