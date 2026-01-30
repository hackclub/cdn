# frozen_string_literal: true

require "test_helper"

class API::V4::UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_key = @user.api_keys.create!(name: "Test Key")
    @token = @api_key.token
  end

  test "should upload file with valid token" do
    file = fixture_file_upload("test.png", "image/png")

    assert_difference("Upload.count", 1) do
      post api_v4_upload_url,
        params: { file: file },
        headers: { "Authorization" => "Bearer #{@token}" }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
    assert_equal "test.png", json["filename"]
    assert json["url"].present?
    assert json["created_at"].present?
  end

  test "should reject upload without token" do
    file = fixture_file_upload("test.png", "image/png")

    post api_v4_upload_url, params: { file: file }

    assert_response :unauthorized
  end

  test "should reject upload without file parameter" do
    post api_v4_upload_url,
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Missing file parameter", json["error"]
  end

  test "should upload from URL with valid token" do
    url = "https://example.com/test.jpg"

    # Stub the URI.open call
    file_double = StringIO.new("fake image data")
    URI.stub :open, file_double do
      assert_difference("Upload.count", 1) do
        post api_v4_upload_from_url_url,
          params: { url: url }.to_json,
          headers: {
            "Authorization" => "Bearer #{@token}",
            "Content-Type" => "application/json"
          }
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
    assert json["url"].present?
  end

  test "should reject upload from URL without url parameter" do
    post api_v4_upload_from_url_url,
      params: {}.to_json,
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Content-Type" => "application/json"
      }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Missing url parameter", json["error"]
  end

  test "should handle upload errors gracefully" do
    url = "https://example.com/broken.jpg"

    # Simulate an error
    URI.stub :open, ->(_) { raise StandardError, "Network error" } do
      post api_v4_upload_from_url_url,
        params: { url: url }.to_json,
        headers: {
          "Authorization" => "Bearer #{@token}",
          "Content-Type" => "application/json"
        }
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].include?("Upload failed")
  end
end
