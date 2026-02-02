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
    uploaded_files = Array(params[:files]).reject(&:blank?)

    if uploaded_files.empty?
      redirect_to uploads_path, alert: "Please select at least one file to upload."
      return
    end

    success_count = 0
    errors = []

    uploaded_files.each do |uploaded_file|
      blob = ActiveStorage::Blob.create_and_upload!(
        io: uploaded_file.tempfile,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type
      )

      current_user.uploads.create!(
        blob: blob,
        provenance: :web
      )
      success_count += 1
    rescue StandardError => e
      Sentry.capture_exception(e)
      errors << "#{uploaded_file.original_filename}: #{e.message}"
    end

    if errors.any?
      redirect_to uploads_path, alert: "#{success_count} file(s) uploaded. Errors: #{errors.join(', ')}"
    else
      redirect_to uploads_path, notice: "#{success_count} #{'file'.pluralize(success_count)} uploaded successfully!"
    end
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
    uploaded_files = Array(params[:files]).reject(&:blank?)
    return if uploaded_files.empty? # Let create action handle missing files

    quota_service = QuotaService.new(current_user)
    policy = quota_service.current_policy
    total_size = uploaded_files.sum(&:size)

    # Check per-file size limit for each file
    uploaded_files.each do |uploaded_file|
      if uploaded_file.size > policy.max_file_size
        redirect_to uploads_path, alert: "File '#{uploaded_file.original_filename}' (#{ActiveSupport::NumberHelper.number_to_human_size(uploaded_file.size)}) exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file."
        return
      end
    end

    # Check if uploads would exceed total storage quota
    unless quota_service.can_upload?(total_size)
      usage = quota_service.current_usage
      redirect_to uploads_path, alert: "Uploading these files would exceed your storage quota. You're using #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_used])} of #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_limit])}."
      nil
    end
  end

  def set_upload
    @upload = Upload.find(params[:id])
  end
end
