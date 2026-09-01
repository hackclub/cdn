require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "homepage renders for signed out visitors" do
    get root_url

    assert_response :success
  end

  test "homepage exposes the metadata signals agents use for entity resolution" do
    get root_url

    assert_select "html[lang=?]", "en"
    assert_select "link[rel=canonical][href=?]", "https://cdn.hackclub.com/"
    assert_select "meta[property='og:type'][content=?]", "website"
    assert_select "meta[property='og:image'][content=?]", "https://cdn.hackclub.com/icon.png"
    assert_select "meta[property='og:url'][content=?]", "https://cdn.hackclub.com/"
    assert_select "meta[property='og:site_name'][content=?]", "Hack Club CDN"
    assert_select "meta[name=description]"
    assert_select "title", "Hack Club CDN"
  end

  test "homepage links to the machine-readable API description" do
    get root_url

    assert_select "link[rel='service-desc'][href=?]", "/openapi.json"
    assert_select "link[rel='service-doc'][href=?]", "/docs/api"
  end

  test "homepage links to the sitemap and the agent instruction file" do
    get root_url

    assert_select "link[rel=sitemap][href=?]", "/sitemap.xml"
    assert_select "link[rel=alternate][type='text/plain'][href=?]", "/llms.txt"
  end

  test "homepage publishes JSON-LD identifying the app and its publisher" do
    get root_url

    scripts = css_select("script[type='application/ld+json']")
    assert_equal 1, scripts.size

    data = JSON.parse(scripts.first.text)
    assert_equal "https://schema.org", data["@context"]

    by_type = data["@graph"].index_by { |node| node["@type"] }
    assert_equal %w[SoftwareApplication Organization WebSite].sort, by_type.keys.sort

    app = by_type["SoftwareApplication"]
    assert_equal "Hack Club CDN", app["name"]
    assert_equal "https://cdn.hackclub.com", app["url"]
    assert app["description"].present?
    assert app["offers"].present?
    assert_includes app["sameAs"], "https://github.com/hackclub/cdn"

    assert_equal "Hack Club", by_type["Organization"]["name"]
    assert by_type["Organization"]["sameAs"].present?
    assert_equal "https://cdn.hackclub.com", by_type["WebSite"]["url"]
  end

  test "canonical URL reflects the current page, not the request host" do
    get doc_url(id: "api")

    assert_response :success
    assert_select "link[rel=canonical][href=?]", "https://cdn.hackclub.com/docs/api"
  end
end
