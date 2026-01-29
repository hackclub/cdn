# frozen_string_literal: true

require "test_helper"

class APIKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get api_keys_url
    assert_response :success
  end

  test "should create api key" do
    assert_difference("APIKey.count", 1) do
      post api_keys_url, params: { api_key: { name: "New Key" } }
    end

    assert_redirected_to api_keys_url
    assert flash[:api_key_token].present?
    assert flash[:api_key_token].start_with?("sk_cdn_")
  end

  test "should not create api key without name" do
    assert_no_difference("APIKey.count") do
      post api_keys_url, params: { api_key: { name: "" } }
    end

    assert_redirected_to api_keys_url
    assert flash[:alert].present?
  end

  test "should revoke api key" do
    api_key = @user.api_keys.create!(name: "Test Key")

    delete api_key_url(api_key)

    assert_redirected_to api_keys_url
    assert api_key.reload.revoked
  end

  test "should not allow revoking other users api keys" do
    other_user = users(:two)
    api_key = other_user.api_keys.create!(name: "Other Key")

    delete api_key_url(api_key)

    assert_redirected_to api_keys_url
    assert flash[:alert].present?
    assert_not api_key.reload.revoked
  end
end
