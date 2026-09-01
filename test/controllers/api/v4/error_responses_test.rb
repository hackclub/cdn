# frozen_string_literal: true

require "test_helper"

class API::V4::ErrorResponsesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_key = @user.api_keys.create!(name: "Test Key")
    @token = @api_key.token
    @auth = { "Authorization" => "Bearer #{@token}" }
  end

  test "missing credentials produce a structured 401" do
    get api_v4_me_url

    assert_response :unauthorized
    json = assert_error_envelope(code: "invalid_auth", status: 401)
    assert_equal "invalid_auth", json["error"]
    assert_includes json["hint"], "/api_keys"
  end

  test "revoked keys produce a structured 401" do
    @api_key.revoke!

    get api_v4_me_url, headers: @auth

    assert_response :unauthorized
    assert_error_envelope(code: "invalid_auth", status: 401)
  end

  test "missing file parameter names the parameter and keeps the legacy error string" do
    post api_v4_upload_url, headers: @auth

    assert_response :bad_request
    json = assert_error_envelope(code: "missing_parameter", status: 400)
    assert_equal "Missing file parameter", json["error"]
    assert_equal "file", json["parameter"]
  end

  test "missing url parameter produces a structured 400" do
    post api_v4_upload_from_url_url, headers: @auth

    assert_response :bad_request
    json = assert_error_envelope(code: "missing_parameter", status: 400)
    assert_equal "Missing url parameter", json["error"]
    assert_equal "url", json["parameter"]
  end

  test "missing files[] parameter produces a structured 400" do
    post api_v4_uploads_url, headers: @auth

    assert_response :bad_request
    json = assert_error_envelope(code: "missing_parameter", status: 400)
    assert_equal "Missing files[] parameter", json["error"]
  end

  test "missing ids[] parameter produces a structured 400" do
    delete api_v4_uploads_batch_delete_url, headers: @auth

    assert_response :bad_request
    json = assert_error_envelope(code: "missing_parameter", status: 400)
    assert_equal "Missing ids[] parameter", json["error"]
  end

  test "deleting an unknown upload produces a structured 404" do
    delete "/api/v4/upload/#{SecureRandom.uuid}", headers: @auth

    assert_response :not_found
    json = assert_error_envelope(code: "not_found", status: 404)
    assert_equal "Not found", json["error"]
  end

  test "renaming an unknown upload produces a structured 404" do
    patch api_v4_upload_rename_url(id: SecureRandom.uuid),
      params: { filename: "new.png" },
      headers: @auth

    assert_response :not_found
    json = assert_error_envelope(code: "upload_not_found", status: 404)
    assert_equal "Upload not found", json["error"]
  end

  test "renaming without a filename produces a structured 400" do
    upload = create_upload

    patch api_v4_upload_rename_url(id: upload["id"]), params: { filename: "  " }, headers: @auth

    assert_response :bad_request
    json = assert_error_envelope(code: "missing_parameter", status: 400)
    assert_equal "Missing filename parameter", json["error"]
    assert_equal "filename", json["parameter"]
  end

  test "exceeding the per-file size limit produces a structured 402 with quota details" do
    stub_max_file_size(1) do
      post api_v4_upload_url,
        params: { file: fixture_file_upload("test.png", "image/png") },
        headers: @auth
    end

    assert_response :payment_required
    json = assert_error_envelope(code: "file_too_large", status: 402)
    assert_includes json["error"], "File size exceeds your limit"
    assert json["quota"]["storage_limit"].present?
    assert json["quota"]["quota_tier"].present?
  end

  private

  def assert_error_envelope(code:, status:)
    assert_equal "application/json", response.media_type
    json = JSON.parse(response.body)

    assert_equal code, json["code"]
    assert_equal status, json["status"]
    assert json["error"].present?, "expected an error string"
    assert json["message"].present?, "expected a human-readable message"
    assert json["hint"].present?, "expected a resolution hint"
    assert_equal "https://cdn.hackclub.com/docs/api", json["documentation_url"]

    json
  end

  def create_upload
    post api_v4_upload_url,
      params: { file: fixture_file_upload("test.png", "image/png") },
      headers: @auth
    assert_response :created
    JSON.parse(response.body)
  end

  def stub_max_file_size(bytes)
    policy = QuotaService.new(@user).current_policy
    stubbed = Quota::Policy[policy.slug, bytes, policy.max_total_storage]
    original = QuotaService.instance_method(:current_policy)

    QuotaService.define_method(:current_policy) { stubbed }
    begin
      yield
    ensure
      QuotaService.define_method(:current_policy, original)
    end
  end
end
