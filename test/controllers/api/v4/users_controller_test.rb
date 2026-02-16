# frozen_string_literal: true

require "test_helper"

class API::V4::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_key = @user.api_keys.create!(name: "Test Key")
    @token = @api_key.token
  end

  test "should get user info with valid token" do
    get api_v4_me_url, headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.public_id, json["id"]
    assert_equal @user.email, json["email"]
    assert_equal @user.name, json["name"]
  end

  test "should reject request without token" do
    get api_v4_me_url

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_auth", json["error"]
  end

  test "should reject request with invalid token" do
    get api_v4_me_url, headers: { "Authorization" => "Bearer sk_cdn_invalid" }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_auth", json["error"]
  end

  test "should reject request with revoked token" do
    @api_key.revoke!

    get api_v4_me_url, headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_auth", json["error"]
  end
end
