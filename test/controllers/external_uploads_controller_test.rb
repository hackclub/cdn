require "test_helper"

class ExternalUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @file_path = external_upload_path(id: SecureRandom.uuid, filename: "test.png")
  end

  test "preflight permits range requests" do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    options @file_path, headers: {
      "Origin" => "https://example.com",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "range, x-accept-encoding"
    }

    assert_response :no_content
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_equal "*", response.headers["Access-Control-Allow-Headers"]
    assert_equal "GET, HEAD", response.headers["Access-Control-Allow-Methods"]
    assert_equal "86400", response.headers["Access-Control-Max-Age"]
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "missing file returns a structured JSON error when JSON is requested" do
    get "/#{SecureRandom.uuid}/missing", headers: { "Accept" => "application/json" }

    assert_response :not_found
    assert_equal "application/json", response.media_type
    json = JSON.parse(response.body)
    assert_equal "not_found", json["code"]
    assert json["message"].present?
    assert json["hint"].present?
    assert_equal "https://cdn.hackclub.com/docs/api", json["documentation_url"]
  end

  test "missing file still returns a bare 404 for image and browser clients" do
    get @file_path

    assert_response :not_found
    assert_empty response.body
  end

  test "rescue without a url returns a structured JSON error when JSON is requested" do
    get rescue_upload_path, headers: { "Accept" => "application/json" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "missing_parameter", json["code"]
    assert_equal "url", json["parameter"]
  end

  test "rescue without a url still returns a bare 400 for browsers" do
    get rescue_upload_path

    assert_response :bad_request
    assert_empty response.body
  end

  test "rescue reports an unknown original URL as JSON when JSON is requested" do
    get rescue_upload_path(url: "https://example.com/gone.png"),
      headers: { "Accept" => "application/json" }

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "original_url_not_found", json["code"]
    assert_equal "https://example.com/gone.png", json["original_url"]
  end

  test "rescue still renders the placeholder image for unknown image URLs" do
    get rescue_upload_path(url: "https://example.com/gone.png")

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, "Original URL not found in CDN"
  end
end
