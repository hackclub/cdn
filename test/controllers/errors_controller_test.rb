# frozen_string_literal: true

require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "unknown API paths return a structured JSON error" do
    get "/api/v4/does_not_exist"

    assert_response :not_found
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "route_not_found", json["code"]
    assert_equal "route_not_found", json["error"]
    assert_equal 404, json["status"]
    assert_includes json["message"], "/api/v4/does_not_exist"
    assert_includes json["message"], "GET"
    assert json["hint"].present?
    assert_equal "https://cdn.hackclub.com/docs/api", json["documentation_url"]
    assert_equal "https://cdn.hackclub.com/openapi.json", json["openapi_url"]
  end

  test "unknown API paths return JSON for non-GET verbs too" do
    post "/api/v4/nope"

    assert_response :not_found
    assert_equal "application/json", response.media_type
    json = JSON.parse(response.body)
    assert_equal "route_not_found", json["code"]
    assert_equal "POST", json["method"]
  end

  test "unknown paths return JSON when the client asks for JSON" do
    get "/not-a-real-page", headers: { "Accept" => "application/json" }

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal "route_not_found", JSON.parse(response.body)["code"]
  end

  test "unknown paths still return the HTML 404 page for browsers" do
    get "/not-a-real-page", headers: { "Accept" => "text/html" }

    assert_response :not_found
    refute_equal "application/json", response.media_type
  end

  test "known API endpoints are not swallowed by the catch-all" do
    get api_v4_me_url

    assert_response :unauthorized
    assert_equal "invalid_auth", JSON.parse(response.body)["code"]
  end
end
