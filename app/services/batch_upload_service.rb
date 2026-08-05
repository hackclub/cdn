# frozen_string_literal: true

class BatchUploadService
  MAX_FILES_PER_BATCH = 40

  Result = Data.define(:uploads, :failed)
  FailedUpload = Data.define(:filename, :reason)

  def initialize(user:, provenance:)
    @user = user
    @provenance = provenance
    @quota_service = QuotaService.new(user)
    @policy = @quota_service.current_policy
  end

  # Validates the whole batch against quota BEFORE writing anything, so a batch
  # that doesn't fit is reported up front instead of failing part-way through
  # with files already persisted.
  def process_files(files)
    files, failed = enforce_batch_limit(files)

    accepted, rejected = validate_against_quota(files)
    failed.concat(rejected)

    uploads = perform_uploads(accepted, failed)

    # Concurrent uploads from another request may still have pushed the user
    # over between validation and here, so re-check and reclaim.
    enforce_quota_after_upload!(uploads, failed) if uploads.any?

    Result[uploads, failed]
  end

  private

  def enforce_batch_limit(files)
    return [ files, [] ] if files.size <= MAX_FILES_PER_BATCH

    rejected = files[MAX_FILES_PER_BATCH..].map do |file|
      FailedUpload[file.original_filename, "Too many files in batch (maximum is #{MAX_FILES_PER_BATCH})"]
    end

    [ files.first(MAX_FILES_PER_BATCH), rejected ]
  end

  # Pure decision pass — performs no writes. Returns the files that fit within
  # quota and a failure for every file that does not.
  def validate_against_quota(files)
    accepted = []
    rejected = []

    # Fresh read to minimize stale data window
    current_storage = @user.reload.total_storage_bytes
    max_storage = @policy.max_total_storage

    # Reject early if already over quota
    if current_storage >= max_storage
      rejected = files.map { |file| FailedUpload[file.original_filename, "Storage quota already exceeded"] }
      return [ accepted, rejected ]
    end

    batch_bytes_used = 0

    files.each do |file|
      filename = file.original_filename
      file_size = file.size

      if file_size > @policy.max_file_size
        rejected << FailedUpload[
          filename,
          "File size (#{human_size(file_size)}) exceeds limit of #{human_size(@policy.max_file_size)}"
        ]
        next
      end

      projected_total = current_storage + batch_bytes_used + file_size
      if projected_total > max_storage
        remaining = [ max_storage - current_storage - batch_bytes_used, 0 ].max
        rejected << FailedUpload[
          filename,
          "Would exceed storage quota (#{human_size(remaining)} remaining)"
        ]
        next
      end

      accepted << file
      batch_bytes_used += file_size
    end

    [ accepted, rejected ]
  end

  def perform_uploads(accepted, failed)
    accepted.each_with_object([]) do |file, uploads|
      uploads << create_upload(file)
    rescue StandardError => e
      Rails.logger.error("BatchUploadService upload failed for #{file.original_filename}: #{e.class}: #{e.message}")
      failed << FailedUpload[file.original_filename, "Upload failed due to an internal error"]
    end
  end

  def enforce_quota_after_upload!(uploads, failed)
    actual_total = @user.reload.total_storage_bytes
    max_storage = @policy.max_total_storage

    return if actual_total <= max_storage

    overage = actual_total - max_storage
    reclaimed = 0
    destroyed_ids = []

    uploads.reverse.each do |upload|
      break if reclaimed >= overage

      reclaimed += upload.byte_size
      destroyed_ids << upload.id
      failed << FailedUpload[upload.filename.to_s, "Removed: concurrent uploads exceeded quota"]
      upload.destroy!
    end

    uploads.reject! { |u| destroyed_ids.include?(u.id) }
  end

  def create_upload(file)
    content_type = Marcel::MimeType.for(file.tempfile, name: file.original_filename) ||
                   file.content_type ||
                   "application/octet-stream"
    content_type = Upload.normalize_content_type(content_type)

    upload_id = SecureRandom.uuid_v7
    sanitized_filename = ActiveStorage::Filename.new(file.original_filename).sanitized
    storage_key = "#{upload_id}/#{sanitized_filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: content_type,
      key: storage_key
    )

    @user.uploads.create!(
      id: upload_id,
      blob: blob,
      provenance: @provenance
    )
  end

  def human_size(bytes)
    ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end
end
