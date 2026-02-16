# frozen_string_literal: true

require "test_helper"

class APIKeyTest < ActiveSupport::TestCase
  test "generates token on create" do
    user = users(:one)
    api_key = user.api_keys.create!(name: "Test Key")

    assert api_key.token.present?
    assert api_key.token.start_with?("sk_cdn_")
  end

  test "token is encrypted in database" do
    user = users(:one)
    api_key = user.api_keys.create!(name: "Test Key")

    # Check that the ciphertext is different from the plaintext
    raw_record = APIKey.connection.select_one(
      "SELECT token_ciphertext FROM api_keys WHERE id = #{api_key.id}"
    )
    assert_not_equal api_key.token, raw_record["token_ciphertext"]
  end

  test "find_by_token uses blind index" do
    user = users(:one)
    api_key = user.api_keys.create!(name: "Test Key")
    token = api_key.token

    found = APIKey.find_by_token(token)
    assert_equal api_key.id, found.id
  end

  test "find_by_token returns nil for invalid token" do
    found = APIKey.find_by_token("sk_cdn_invalid_token")
    assert_nil found
  end

  test "active scope excludes revoked keys" do
    active_count = APIKey.active.count
    APIKey.create!(user: users(:one), name: "New Key")

    assert_equal active_count + 1, APIKey.active.count
  end

  test "revoke! marks key as revoked" do
    api_key = api_keys(:one)
    assert api_key.active?

    api_key.revoke!

    assert api_key.revoked
    assert_not api_key.active?
    assert api_key.revoked_at.present?
  end

  test "masked_token shows prefix and suffix" do
    user = users(:one)
    api_key = user.api_keys.create!(name: "Test Key")

    masked = api_key.masked_token
    assert masked.include?("sk_cdn_")
    assert masked.include?("....")
    assert_equal 23, masked.length  # "sk_cdn_" (7) + 6 chars + "...." (4) + 6 chars
  end

  test "validates name presence" do
    api_key = APIKey.new(user: users(:one))
    assert_not api_key.valid?
    assert_includes api_key.errors[:name], "can't be blank"
  end
end
