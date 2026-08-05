# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :set_upload, only: [ :update, :destroy ]

  def index
    @uploads = current_user.uploads.includes(:blob).recent

    if params[:query].present?
      @uploads = @uploads.search_by_filename(params[:query])
    end

    @uploads = @uploads.page(params[:page]).per(50)
  end

  def create
    uploaded_files = extract_uploaded_files

    if uploaded_files.empty?
      redirect_to uploads_path, alert: "Please select at least one file to upload."
      return
    end

    if uploaded_files.size > BatchUploadService::MAX_FILES_PER_BATCH
      redirect_to uploads_path, alert: "Too many files selected. Max #{BatchUploadService::MAX_FILES_PER_BATCH} files allowed per upload."
      return
    end

    service = BatchUploadService.new(user: current_user, provenance: :web)
    result = service.process_files(uploaded_files)

    flash_message = build_flash_message(result)

    if result.uploads.any?
      redirect_to uploads_path, notice: flash_message
    else
      redirect_to uploads_path, alert: flash_message
    end
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    redirect_to uploads_path, alert: "Upload failed: #{e.message} (Error ID: #{event&.event_id})"
  end

  def update
    authorize @upload

    new_filename = params[:filename].to_s.strip
    if new_filename.blank?
      redirect_to uploads_path, alert: "Filename can't be blank."
      return
    end

    @upload.rename!(new_filename)
    redirect_to uploads_path, notice: "Renamed to #{@upload.filename}"
  rescue Pundit::NotAuthorizedError
    redirect_back fallback_location: uploads_path, alert: "You are not authorized to rename this upload."
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    redirect_back fallback_location: uploads_path, alert: "Rename failed. (Error ID: #{event&.event_id})"
  end

  def destroy
    authorize @upload

    @upload.destroy!
    redirect_back fallback_location: uploads_path, notice: "Upload deleted successfully."
  rescue Pundit::NotAuthorizedError
    redirect_back fallback_location: uploads_path, alert: "You are not authorized to delete this upload."
  end

  def destroy_batch
    ids = Array(params[:ids]).reject(&:blank?)

    if ids.empty?
      redirect_to uploads_path, alert: "No files selected."
      return
    end

    uploads = current_user.uploads.where(id: ids).includes(:blob)
    count = uploads.size

    uploads.destroy_all

    redirect_to uploads_path, notice: "Deleted #{count} #{'file'.pluralize(count)}."
  end

  private

  def extract_uploaded_files
    files = []
    files.concat(Array(params[:files])) if params[:files].present?
    files << params[:file] if params[:file].present?
    files.reject(&:blank?)
  end

  def build_flash_message(result)
    parts = []

    if result.uploads.any?
      count = result.uploads.size
      names = result.uploads.map { |u| u.filename.to_s }
      if names.size <= 5
        parts << "Uploaded #{count} #{'file'.pluralize(count)}: #{names.join(', ')}"
      else
        parts << "Uploaded #{count} #{'file'.pluralize(count)}: #{names.first(5).join(', ')} and #{count - 5} more"
      end
    end

    if result.failed.any?
      failed_count = result.failed.size
      failed_names = result.failed.map(&:filename)
      if failed_names.size <= 5
        parts << "Failed to upload #{failed_count} #{'file'.pluralize(failed_count)}: #{failed_names.join(', ')}"
      else
        parts << "Failed to upload #{failed_count} #{'file'.pluralize(failed_count)}: #{failed_names.first(5).join(', ')} and #{failed_count - 5} more"
      end
    end

    parts.join(". ")
  end

  def set_upload
    @upload = Upload.find(params[:id])
  end
end
