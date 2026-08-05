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

    fake_response = Struct.new(:status, :body, :headers) { def success? = true }
                          .new(200, "fake image data", { "content-type" => "image/jpeg" })
    fake_opts = Object.new.tap { |o| o.define_singleton_method(:open_timeout=) { |_| }
                                     o.define_singleton_method(:timeout=) { |_| } }
    fake_head_response = Struct.new(:status, :body, :headers) { def success? = false }
                               .new(405, "", {})
    fake_conn = Object.new.tap { |c| c.define_singleton_method(:options) { fake_opts }
                                     c.define_singleton_method(:get) { |*| fake_response }
                                     c.define_singleton_method(:head) { |*| fake_head_response } }

    original_faraday_new = Faraday.method(:new)
    original_assert_public_url = Upload.method(:assert_public_url!)
    Faraday.define_singleton_method(:new) { |*, **, &_block| fake_conn }
    Upload.define_singleton_method(:assert_public_url!) { |_url| nil }
    begin
      assert_difference("Upload.count", 1) do
        post api_v4_upload_from_url_url,
          params: { url: url }.to_json,
          headers: {
            "Authorization" => "Bearer #{@token}",
            "Content-Type" => "application/json"
          }
      end
    ensure
      Faraday.define_singleton_method(:new, original_faraday_new)
      Upload.define_singleton_method(:assert_public_url!, original_assert_public_url)
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

    fake_opts = Object.new.tap { |o| o.define_singleton_method(:open_timeout=) { |_| }
                                     o.define_singleton_method(:timeout=) { |_| } }
    fake_conn = Object.new.tap { |c| c.define_singleton_method(:options) { fake_opts }
                                     c.define_singleton_method(:get) { |*| raise StandardError, "Network error" } }

    original_faraday_new = Faraday.method(:new)
    original_assert_public_url = Upload.method(:assert_public_url!)
    Faraday.define_singleton_method(:new) { |*, **, &_block| fake_conn }
    Upload.define_singleton_method(:assert_public_url!) { |_url| nil }
    begin
      post api_v4_upload_from_url_url,
        params: { url: url }.to_json,
        headers: {
          "Authorization" => "Bearer #{@token}",
          "Content-Type" => "application/json"
        }
    ensure
      Faraday.define_singleton_method(:new, original_faraday_new)
      Upload.define_singleton_method(:assert_public_url!, original_assert_public_url)
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].include?("Upload failed")
  end

  # --- batch upload ---

  test "should upload a batch of files" do
    files = [ fixture_file_upload("test.png", "image/png"), fixture_file_upload("test.png", "image/png") ]

    assert_difference("Upload.count", 2) do
      post api_v4_uploads_url,
        params: { files: files },
        headers: { "Authorization" => "Bearer #{@token}" }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["uploads"].size
    assert_empty json["failed"]
    assert json["uploads"].all? { |u| u["url"].present? }
  end

  test "should reject a batch without files parameter" do
    post api_v4_uploads_url, headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :bad_request
    assert_equal "Missing files[] parameter", JSON.parse(response.body)["error"]
  end

  test "should reject a batch over the file count limit before uploading anything" do
    files = (BatchUploadService::MAX_FILES_PER_BATCH + 1).times.map { fixture_file_upload("test.png", "image/png") }

    assert_no_difference("Upload.count") do
      post api_v4_uploads_url,
        params: { files: files },
        headers: { "Authorization" => "Bearer #{@token}" }
    end

    assert_response :bad_request
    assert_equal "Too many files", JSON.parse(response.body)["error"]
  end

  # --- batch delete ---

  test "should delete a batch of uploads and report unknown ids" do
    a = create_upload("a.png")
    b = create_upload("b.png")
    unknown = SecureRandom.uuid_v7

    assert_difference("Upload.count", -2) do
      delete api_v4_uploads_batch_delete_url,
        params: { ids: [ a.id, b.id, unknown ] }.to_json,
        headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["deleted"].size
    assert_equal [ unknown ], json["not_found"]
  end

  test "should not batch delete another user's uploads" do
    theirs = create_upload("theirs.png", user: users(:two))

    assert_no_difference("Upload.count") do
      delete api_v4_uploads_batch_delete_url,
        params: { ids: [ theirs.id ] }.to_json,
        headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
    end

    assert Upload.exists?(theirs.id)
    assert_empty JSON.parse(response.body)["deleted"]
  end

  test "should reject a batch delete without ids" do
    delete api_v4_uploads_batch_delete_url,
      params: { ids: [] }.to_json,
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_equal "Missing ids[] parameter", JSON.parse(response.body)["error"]
  end

  # --- rename ---

  test "should rename an upload and preserve the extension" do
    upload = create_upload("before.png")

    patch api_v4_upload_rename_url(id: upload.id),
      params: { filename: "after" }.to_json,
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }

    assert_response :success
    assert_equal "after.png", JSON.parse(response.body)["filename"]
  end

  test "should not rename another user's upload" do
    theirs = create_upload("theirs.png", user: users(:two))

    patch api_v4_upload_rename_url(id: theirs.id),
      params: { filename: "hacked" }.to_json,
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }

    assert_response :not_found
    assert_equal "theirs.png", theirs.reload.filename.to_s
  end

  test "should reject a blank rename" do
    upload = create_upload("keep.png")

    patch api_v4_upload_rename_url(id: upload.id),
      params: { filename: "  " }.to_json,
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_equal "keep.png", upload.reload.filename.to_s
  end

  private

  def create_upload(filename, user: @user)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("test.png").open,
      filename: filename,
      content_type: "image/png"
    )
    user.uploads.create!(id: SecureRandom.uuid_v7, blob: blob, provenance: :api)
  end
end
