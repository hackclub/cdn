# frozen_string_literal: true

require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  NAMESPACE = { "s" => Sitemap::NAMESPACE }.freeze

  test "serves a sitemap as XML without authentication" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert response.body.start_with?(%(<?xml version="1.0" encoding="UTF-8"?>))
  end

  test "is a valid sitemaps.org 0.9 urlset" do
    get "/sitemap.xml"

    doc = Nokogiri::XML(response.body) { |config| config.strict }
    refute_predicate doc.errors, :any?, doc.errors.join(", ")

    assert_equal "urlset", doc.root.name
    assert_equal Sitemap::NAMESPACE, doc.root.namespace.href

    urls = doc.xpath("//s:url", NAMESPACE)
    assert urls.any?
    assert_operator urls.size, :<=, 50_000, "a single sitemap may list at most 50,000 URLs"
    assert_operator response.body.bytesize, :<, 50.megabytes

    urls.each do |url|
      assert_equal 1, url.xpath("s:loc", NAMESPACE).size, "every <url> needs exactly one <loc>"
    end
  end

  test "lists the homepage and every documentation page, absolutely" do
    get "/sitemap.xml"

    locs = locations(response.body)
    expected = [ "#{Sitemap.base_url}/", *DocPage.all.map { |doc| "#{Sitemap.base_url}#{doc.path}" } ]

    assert_equal expected.sort, locs.sort
    assert_equal locs, locs.uniq, "duplicate <loc> entries"
    locs.each { |loc| assert loc.start_with?("https://"), "#{loc} must be an absolute https URL" }
  end

  test "excludes pages that need a session, redirect, or should not be indexed" do
    get "/sitemap.xml"

    paths = locations(response.body).map { |loc| URI.parse(loc).path }

    [ "/docs", "/login", "/uploads", "/api_keys", "/admin/search", "/up", "/openapi.json" ].each do |path|
      refute_includes paths, path, "#{path} should not be in the sitemap"
    end
  end

  test "every listed URL returns 200 to an anonymous visitor" do
    get "/sitemap.xml"

    locations(response.body).each do |loc|
      get URI.parse(loc).request_uri
      assert_response :success, "#{loc} is in the sitemap but did not return 200"
    end
  end

  test "every entry carries a W3C datetime lastmod and a valid changefreq" do
    get "/sitemap.xml"

    doc = Nokogiri::XML(response.body)
    urls = doc.xpath("//s:url", NAMESPACE)

    urls.each do |url|
      lastmod = url.at_xpath("s:lastmod", NAMESPACE)
      assert lastmod.present?, "every <url> needs a <lastmod>"
      assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, lastmod.text)
      assert_operator Time.iso8601(lastmod.text), :<=, Time.current.end_of_day

      changefreq = url.at_xpath("s:changefreq", NAMESPACE)
      assert_includes %w[always hourly daily weekly monthly yearly never], changefreq.text
    end
  end

  test "documentation lastmod tracks the source markdown file" do
    doc = DocPage.all.first
    entry = Sitemap.entries.find { |candidate| candidate.loc.end_with?(doc.path) }

    assert_equal doc.updated_at.utc.iso8601, entry.lastmod.utc.iso8601
  end

  test "robots.txt advertises the sitemap at the canonical host" do
    robots = Rails.root.join("public/robots.txt").read

    assert_includes robots, "Sitemap: https://cdn.hackclub.com/sitemap.xml"
    assert_includes robots, "User-agent: *"
  end

  test "is cacheable and readable cross-origin" do
    get "/sitemap.xml"

    assert_includes response.headers["Cache-Control"], "public"
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  private

  def locations(body)
    Nokogiri::XML(body).xpath("//s:url/s:loc", NAMESPACE).map(&:text)
  end
end
