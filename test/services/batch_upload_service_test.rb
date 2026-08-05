# frozen_string_literal: true

require "test_helper"

class BatchUploadServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # quota_policy nil + no HCA token => unverified tier (10 MB/file, 50 MB total)
    @user.update!(quota_policy: nil, hca_access_token: nil)
    @policy = Quota.policy(:unverified)
  end

  # Builds an in-memory uploaded file of the requested size
  def uploaded_file(name, size)
    tempfile = Tempfile.new([ "batch", File.extname(name) ])
    tempfile.binmode
    tempfile.write("a" * size)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: name,
      type: "text/plain"
    )
  end

  def service
    BatchUploadService.new(user: @user, provenance: :web)
  end

  test "uploads every file when the whole batch fits in quota" do
    files = 3.times.map { |i| uploaded_file("file#{i}.txt", 1.megabyte) }

    result = nil
    assert_difference("Upload.count", 3) do
      result = service.process_files(files)
    end

    assert_equal 3, result.uploads.size
    assert_empty result.failed
  end

  test "rejects a file larger than the per-file limit without uploading it" do
    files = [
      uploaded_file("ok.txt", 1.megabyte),
      uploaded_file("huge.txt", @policy.max_file_size + 1)
    ]

    result = nil
    assert_difference("Upload.count", 1) do
      result = service.process_files(files)
    end

    assert_equal [ "ok.txt" ], result.uploads.map { |u| u.filename.to_s }
    assert_equal [ "huge.txt" ], result.failed.map(&:filename)
    assert_match(/exceeds limit/, result.failed.first.reason)
  end

  test "counts cumulative batch size so the batch cannot exceed total quota" do
    # 50 MB total quota, 10 MB per file -> only 5 of these 7 can fit
    files = 7.times.map { |i| uploaded_file("f#{i}.txt", 10.megabytes) }

    result = nil
    assert_difference("Upload.count", 5) do
      result = service.process_files(files)
    end

    assert_equal 5, result.uploads.size
    assert_equal 2, result.failed.size
    assert(result.failed.all? { |f| f.reason.match?(/exceed storage quota/) })
    assert_operator @user.reload.total_storage_bytes, :<=, @policy.max_total_storage
  end

  test "quota decisions are made before any file is written" do
    # The 2nd file blows the per-file limit; nothing should be written until
    # every file in the batch has been validated.
    files = [
      uploaded_file("a.txt", 1.megabyte),
      uploaded_file("too-big.txt", @policy.max_file_size + 1),
      uploaded_file("b.txt", 1.megabyte)
    ]

    validated_before_first_write = false
    original_create = ActiveStorage::Blob.method(:create_and_upload!)
    ActiveStorage::Blob.define_singleton_method(:create_and_upload!) do |**kwargs|
      validated_before_first_write = true
      original_create.call(**kwargs)
    end

    begin
      result = service.process_files(files)
    ensure
      ActiveStorage::Blob.define_singleton_method(:create_and_upload!, original_create)
    end

    assert validated_before_first_write, "expected uploads to run"
    # The oversized file was reported, and both valid files still went through
    assert_equal %w[a.txt b.txt], result.uploads.map { |u| u.filename.to_s }
    assert_equal [ "too-big.txt" ], result.failed.map(&:filename)
  end

  test "rejects the entire batch when the user is already over quota" do
    files = 2.times.map { |i| uploaded_file("f#{i}.txt", 1.megabyte) }

    over = @policy.max_total_storage + 1
    @user.define_singleton_method(:total_storage_bytes) { over }
    @user.define_singleton_method(:reload) { self }

    result = nil
    assert_no_difference("Upload.count") do
      result = service.process_files(files)
    end

    assert_empty result.uploads
    assert_equal 2, result.failed.size
    assert(result.failed.all? { |f| f.reason == "Storage quota already exceeded" })
  end

  test "rejects files beyond the per-batch file count limit" do
    files = (BatchUploadService::MAX_FILES_PER_BATCH + 2).times.map { |i| uploaded_file("f#{i}.txt", 1.kilobyte) }

    result = service.process_files(files)

    assert_equal BatchUploadService::MAX_FILES_PER_BATCH, result.uploads.size
    assert_equal 2, result.failed.size
    assert(result.failed.all? { |f| f.reason.match?(/Too many files in batch/) })
  end

  test "passes a normalized content type to the blob, like the single-upload path" do
    captured = nil
    original_create = ActiveStorage::Blob.method(:create_and_upload!)
    ActiveStorage::Blob.define_singleton_method(:create_and_upload!) do |**kwargs|
      captured = kwargs[:content_type]
      original_create.call(**kwargs)
    end

    begin
      service.process_files([ uploaded_file("note.txt", 128) ])
    ensure
      ActiveStorage::Blob.define_singleton_method(:create_and_upload!, original_create)
    end

    assert_equal Upload.normalize_content_type("text/plain"), captured
  end
end
