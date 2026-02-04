# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :set_upload, only: [ :destroy ]
  before_action :check_quota, only: [ :create ]

  def index
    @uploads = current_user.uploads.includes(:blob).recent

    if params[:query].present?
      @uploads = @uploads.search_by_filename(params[:query])
    end

    @uploads = @uploads.page(params[:page]).per(50)
  end

  def create
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_to uploads_path, alert: "Please select a file to upload."
      return
    end

    content_type = Marcel::MimeType.for(uploaded_file.tempfile, name: uploaded_file.original_filename) || uploaded_file.content_type || "application/octet-stream"
    # pre-gen upload ID for predictable storage path
    upload_id = SecureRandlom.uuid_v7
    sanatized_filename = ActiveStorage::Filename.new(uploaded_file.original_filename).sanitized
    storage_key = "#{upload_id}/#{sanitized_filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_file.tempfile,
      filename: uploaded_file.original_filename,
      content_type: content_type
    )

    @upload = current_user.uploads.create!(
      blob: blob,
      provenance: :web
    )

    redirect_to uploads_path, notice: "File uploaded successfully!"
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    redirect_to uploads_path, alert: "Upload failed: #{e.message} (Error ID: #{event&.event_id})"
  end

  def destroy
    authorize @upload

    @upload.destroy!
    redirect_back fallback_location: uploads_path, notice: "Upload deleted successfully."
  rescue Pundit::NotAuthorizedError
    redirect_back fallback_location: uploads_path, alert: "You are not authorized to delete this upload."
  end

  private

  def check_quota
    uploaded_file = params[:file]
    return if uploaded_file.blank? # Let create action handle missing file

    quota_service = QuotaService.new(current_user)
    file_size = uploaded_file.size
    policy = quota_service.current_policy

    # Check per-file size limit
    if file_size > policy.max_file_size
      redirect_to uploads_path, alert: "File size (#{ActiveSupport::NumberHelper.number_to_human_size(file_size)}) exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file."
      return
    end

    # Check if upload would exceed total storage quota
    unless quota_service.can_upload?(file_size)
      usage = quota_service.current_usage
      redirect_to uploads_path, alert: "Uploading this file would exceed your storage quota. You're using #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_used])} of #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_limit])}."
      nil
    end
  end

  def set_upload
    @upload = Upload.find(params[:id])
  end
end
