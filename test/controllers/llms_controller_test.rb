# frozen_string_literal: true

require "test_helper"

class LlmsControllerTest < ActionDispatch::IntegrationTest
  # The shape the llms.txt reference parser accepts inside an H2 section:
  # "- [name](url)" with an optional ": description".
  LINK_LINE = /\A- \[[^\]]+\]\([^)\s]+\)(: .+)?\z/

  test "serves the agent instruction file as plain text without authentication" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "utf-8", response.charset
  end

  test "follows the llms.txt format: H1, blockquote summary, then H2 sections" do
    get "/llms.txt"

    lines = response.body.lines.map(&:chomp)
    assert_equal "# Hack Club CDN", lines.first
    assert_empty lines.drop(1).grep(/\A# /), "only the title may be an H1"

    summary = lines.drop(1).find(&:present?)
    assert summary.start_with?("> "), "expected a blockquote summary after the H1, got #{summary.inspect}"

    headings = lines.grep(/\A## /)
    assert_equal headings, headings.uniq, "duplicate H2 sections"
    assert_equal "## When to use this", headings.first
    assert_equal "## Optional", headings.last, "the Optional section must come last"
  end

  test "every H2 section body is a link list, as the format requires" do
    get "/llms.txt"

    sections(response.body).each do |heading, body|
      lines = body.lines.map(&:chomp).select(&:present?)
      assert lines.any?, "section '#{heading}' is empty"

      lines.each do |line|
        assert_match LINK_LINE, line,
          "'#{heading}' contains a non-link line, which the llms.txt parser rejects: #{line.inspect}"
      end
    end
  end

  test "the guidance region carries prose, which may not live under a heading" do
    get "/llms.txt"

    assert_operator info(response.body).length, :>, 2_000,
      "expected substantive guidance before the first H2 section"
  end

  test "names the jobs the service is a good fit for" do
    get "/llms.txt"

    jobs = sections(response.body).fetch("When to use this").lines.map(&:chomp).select(&:present?)
    assert_operator jobs.size, :>=, 5, "when-to-use guidance should name several concrete jobs"

    body = jobs.join("\n")
    assert_includes body, "POST /api/v4/upload"
    assert_includes body, "POST /api/v4/upload_from_url"
    assert_includes body, "GET /api/v4/me"
    assert_includes body, "GET /rescue"
  end

  test "names the jobs the service is the wrong tool for" do
    get "/llms.txt"
    body = info(response.body)

    assert_includes body, "**When not to use this.**"
    assert_includes body, "Every CDN URL is public"
    assert_includes body, "no index endpoint"
    assert_includes body, "no anonymous upload endpoint"
  end

  test "tells agents how to call the API" do
    get "/llms.txt"
    body = info(response.body)

    assert_includes body, "**How to call it.**"
    assert_includes body, "Authorization: Bearer sk_cdn_"
    assert_includes body, "#{LlmsTxt.base_url}/api_keys"
    assert_includes body, "curl -X POST #{LlmsTxt.base_url}/api/v4/upload"
    assert_includes body, "multipart form data"
    assert_includes body, "Branch on the `code` field of errors"
  end

  test "lists every /api/v4 endpoint the app actually routes" do
    get "/llms.txt"
    body = response.body

    api_paths = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub("(.:format)", "")
      path if path.start_with?("/api/v4/")
    end.uniq

    assert api_paths.any?, "expected the app to route /api/v4 endpoints"
    api_paths.each do |path|
      assert_includes body, path, "#{path} is routable but missing from /llms.txt"
    end
  end

  test "quotas and batch limits are read from the code, not hardcoded prose" do
    get "/llms.txt"
    body = response.body

    assert_includes body, "up to #{BatchUploadService::MAX_FILES_PER_BATCH} files"

    Quota::ALL_POLICIES.each_value do |policy|
      assert_includes body, policy.slug.to_s.humanize,
        "quota tier #{policy.slug} is missing from /llms.txt"
      assert_includes body,
        "#{ActiveSupport::NumberHelper.number_to_human_size(policy.max_total_storage)} total",
        "storage limit for #{policy.slug} is missing from /llms.txt"
    end
  end

  test "points agents at the machine-readable API description" do
    get "/llms.txt"
    body = response.body

    assert_includes body, "#{LlmsTxt.base_url}/openapi.json"
    assert_includes body, "OpenAPI #{OpenAPISpec::SPEC_VERSION}"
    assert_includes body, "API version #{OpenAPISpec::API_VERSION}"
  end

  test "links every documentation page with its summary, and each one resolves" do
    get "/llms.txt"
    docs = sections(response.body).fetch("Docs")

    DocPage.all.each do |doc|
      assert_includes docs, "[#{doc.title}](#{LlmsTxt.base_url}#{doc.path}): #{doc.summary}",
        "#{doc.id} is missing from the Docs section of /llms.txt"
    end

    DocPage.all.each do |doc|
      get doc.path
      assert_response :success, "#{doc.path} is linked from /llms.txt but did not return 200"
    end
  end

  test "no link on the site's own host is broken" do
    get "/llms.txt"

    paths = response.body.scan(/\[[^\]]+\]\((#{Regexp.escape(LlmsTxt.base_url)}[^)\s]*)\)/)
      .flatten.map { |url| URI.parse(url).request_uri }.uniq

    assert_operator paths.size, :>=, DocPage.all.size, "expected the doc links to be absolute"

    paths.each do |path|
      get path
      assert_includes 200..399, response.status,
        "#{path} is linked from /llms.txt but returned #{response.status}"
    end
  end

  test "is cacheable and readable cross-origin" do
    get "/llms.txt"

    assert_includes response.headers["Cache-Control"], "public"
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  private

  # { "heading" => "section body" } for every H2 section.
  def sections(body)
    body.split(/^## /).drop(1).to_h do |chunk|
      heading, rest = chunk.split("\n", 2)
      [ heading, rest.to_s ]
    end
  end

  # Everything between the blockquote summary and the first H2 section.
  def info(body)
    body[/^>.*?\n(.*?)(?=^## )/m, 1] || flunk("no guidance region in /llms.txt")
  end
end
