# frozen_string_literal: true

require "test_helper"

class UploadsBatchTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @user.update!(quota_policy: nil, hca_access_token: nil) # unverified: 10 MB/file, 50 MB total
    sign_in @user
  end

  def create_upload_for(user, filename: "existing.png")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("test.png").open,
      filename: filename,
      content_type: "image/png"
    )
    user.uploads.create!(id: SecureRandom.uuid_v7, blob: blob, provenance: :web)
  end

  # --- batch upload ---

  test "uploads multiple files in one request" do
    files = [ fixture_file_upload("test.png", "image/png"), fixture_file_upload("test.png", "image/png") ]

    assert_difference("Upload.count", 2) do
      post uploads_url, params: { files: files }
    end

    assert_redirected_to uploads_path
    assert_match(/Uploaded 2 files/, flash[:notice])
  end

  test "still accepts a single legacy file param" do
    assert_difference("Upload.count", 1) do
      post uploads_url, params: { file: fixture_file_upload("test.png", "image/png") }
    end

    assert_redirected_to uploads_path
    assert_match(/Uploaded 1 file/, flash[:notice])
  end

  test "rejects a batch over the file count limit before uploading anything" do
    files = (BatchUploadService::MAX_FILES_PER_BATCH + 1).times.map do
      fixture_file_upload("test.png", "image/png")
    end

    assert_no_difference("Upload.count") do
      post uploads_url, params: { files: files }
    end

    assert_redirected_to uploads_path
    assert_match(/Too many files selected/, flash[:alert])
  end

  test "reports an alert when every file in the batch is rejected by quota" do
    @user.define_singleton_method(:total_storage_bytes) { 999.gigabytes }

    # controller builds its own User instance, so drive the service directly
    result = BatchUploadService.new(user: @user, provenance: :web)
      .process_files([ fixture_file_upload("test.png", "image/png") ])

    assert_empty result.uploads
    assert_equal 1, result.failed.size
  end

  test "requires at least one file" do
    assert_no_difference("Upload.count") do
      post uploads_url, params: { files: [] }
    end

    assert_redirected_to uploads_path
    assert_match(/select at least one file/, flash[:alert])
  end

  # --- batch delete ---

  test "deletes the selected uploads" do
    a = create_upload_for(@user, filename: "a.png")
    b = create_upload_for(@user, filename: "b.png")

    assert_difference("Upload.count", -2) do
      delete destroy_batch_uploads_url, params: { ids: [ a.id, b.id ] }
    end

    assert_redirected_to uploads_path
    assert_match(/Deleted 2 files/, flash[:notice])
  end

  test "will not delete uploads belonging to another user" do
    mine = create_upload_for(@user, filename: "mine.png")
    theirs = create_upload_for(@other_user, filename: "theirs.png")

    assert_difference("Upload.count", -1) do
      delete destroy_batch_uploads_url, params: { ids: [ mine.id, theirs.id ] }
    end

    assert Upload.exists?(theirs.id), "another user's upload must survive"
    assert_not Upload.exists?(mine.id)
    assert_match(/could not be found and was skipped/, flash[:notice])
  end

  test "deletes nothing when none of the ids belong to the user" do
    theirs = create_upload_for(@other_user, filename: "theirs.png")

    assert_no_difference("Upload.count") do
      delete destroy_batch_uploads_url, params: { ids: [ theirs.id ] }
    end

    assert_match(/None of the selected files could be found/, flash[:alert])
  end

  test "requires at least one id" do
    assert_no_difference("Upload.count") do
      delete destroy_batch_uploads_url, params: { ids: [] }
    end

    assert_match(/No files selected/, flash[:alert])
  end

  # --- rename ---

  test "renames an upload the user owns" do
    upload = create_upload_for(@user, filename: "before.png")

    patch upload_url(upload), params: { filename: "after" }

    assert_redirected_to uploads_path
    assert_equal "after.png", upload.reload.filename.to_s, "extension should be preserved"
  end

  test "will not rename another user's upload" do
    theirs = create_upload_for(@other_user, filename: "theirs.png")

    patch upload_url(theirs), params: { filename: "hacked" }

    assert_equal "theirs.png", theirs.reload.filename.to_s
    assert_match(/not authorized/, flash[:alert])
  end

  test "rejects a blank rename" do
    upload = create_upload_for(@user, filename: "keep.png")

    patch upload_url(upload), params: { filename: "   " }

    assert_equal "keep.png", upload.reload.filename.to_s
    assert_match(/can't be blank/, flash[:alert])
  end
end
