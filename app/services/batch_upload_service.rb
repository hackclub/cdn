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

  def process_files(files)
    uploads = []
    failed = []

    # Enforce batch size limit inside the service
    if files.size > MAX_FILES_PER_BATCH
      files[MAX_FILES_PER_BATCH..].each do |file|
        failed << FailedUpload[file.original_filename, "Too many files in batch (maximum is #{MAX_FILES_PER_BATCH})"]
      end
      files = files.first(MAX_FILES_PER_BATCH)
    end

    # Fresh read to minimize stale data window
    current_storage = @user.reload.total_storage_bytes
    max_storage = @policy.max_total_storage

    # Reject early if already over quota
    if current_storage >= max_storage
      files.each do |file|
        failed << FailedUpload[file.original_filename, "Storage quota already exceeded"]
      end
      return Result[uploads, failed]
    end

    batch_bytes_used = 0

    files.each do |file|
      filename = file.original_filename
      file_size = file.size

      if file_size > @policy.max_file_size
        failed << FailedUpload[
          filename,
          "File size (#{human_size(file_size)}) exceeds limit of #{human_size(@policy.max_file_size)}"
        ]
        next
      end

      projected_total = current_storage + batch_bytes_used + file_size
      if projected_total > max_storage
        remaining = [ max_storage - current_storage - batch_bytes_used, 0 ].max
        failed << FailedUpload[
          filename,
          "Would exceed storage quota (#{human_size(remaining)} remaining)"
        ]
        next
      end

      begin
        upload = create_upload(file)
        uploads << upload
        batch_bytes_used += file_size
      rescue StandardError => e
        Rails.logger.error("BatchUploadService upload failed for #{filename}: #{e.class}: #{e.message}")
        failed << FailedUpload[filename, "Upload failed due to an internal error"]
      end
    end

    enforce_quota_after_upload!(uploads, failed) if uploads.any?

    Result[uploads, failed]
  end

  private

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
