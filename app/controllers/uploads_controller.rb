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

  def activity_ribbon
    user_id = current_user.respond_to?(:id) ? current_user.id : "guest"
    rows = (params[:rows] || 2).to_i

    cache_key = ["user_activity_ribbon_html", user_id, Date.current.to_s, rows]
    ribbon_html = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      counts = if current_user.respond_to?(:uploads)
        current_user.uploads.where("created_at >= ?", 240.days.ago).group("DATE(created_at)").count.transform_keys do |k|
          k.is_a?(String) ? Date.parse(k) : k
        end
      else
        {}
      end

      Components::Uploads::ActivityRibbon.new(
        counts: counts,
        rows: rows,
        cols: 120,
        size: "10px"
      ).call
    end

    response.headers["Cache-Control"] = "private, max-age=300"
    render html: ribbon_html.html_safe, layout: false
  end

  def create
    uploaded_files = extract_uploaded_files

    if uploaded_files.empty?
      respond_to do |format|
        format.html { redirect_to uploads_path, alert: "Please select at least one file to upload." }
        format.json { render json: { success: false, error: "Please select at least one file to upload." }, status: :unprocessable_entity }
      end
      return
    end

    if uploaded_files.size > BatchUploadService::MAX_FILES_PER_BATCH
      error_msg = "Too many files selected. Max #{BatchUploadService::MAX_FILES_PER_BATCH} files allowed per upload."
      respond_to do |format|
        format.html { redirect_to uploads_path, alert: error_msg }
        format.json { render json: { success: false, error: error_msg }, status: :unprocessable_entity }
      end
      return
    end

    service = BatchUploadService.new(user: current_user, provenance: :web)
    result = service.process_files(uploaded_files)

    flash_message = build_flash_message(result)

    if result.uploads.any?
      invalidate_activity_ribbon_cache
    end

    respond_to do |format|
      format.html do
        if result.uploads.any?
          redirect_to uploads_path, notice: flash_message
        else
          redirect_to uploads_path, alert: flash_message
        end
      end
      format.json do
        if result.uploads.any?
          rendered_uploads = result.uploads.map do |u|
            {
              id: u.id,
              filename: u.filename.to_s,
              cdn_url: u.cdn_url,
              human_file_size: u.human_file_size,
              content_type: u.content_type,
              provenance: (u.provenance.to_s == "api" ? "API" : u.provenance.to_s.titleize),
              row_html: render_to_string(Components::Uploads::Row.new(upload: u, compact: false), layout: false)
            }
          end
          render json: { success: true, notice: flash_message, uploads: rendered_uploads }
        else
          render json: { success: false, error: flash_message }, status: :unprocessable_entity
        end
      end
    end
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    respond_to do |format|
      format.html { redirect_to uploads_path, alert: "Upload failed: #{e.message} (Error ID: #{event&.event_id})" }
      format.json { render json: { success: false, error: "Upload failed: #{e.message}" }, status: :internal_server_error }
    end
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

    filename = @upload.filename.to_s
    upload_id = @upload.id
    @upload.destroy!
    invalidate_activity_ribbon_cache

    respond_to do |format|
      format.html { redirect_back fallback_location: uploads_path, notice: "Deleted \"#{filename}\" successfully." }
      format.json { render json: { success: true, notice: "Deleted \"#{filename}\" successfully.", id: upload_id, filename: filename } }
    end
  rescue Pundit::NotAuthorizedError
    respond_to do |format|
      format.html { redirect_back fallback_location: uploads_path, alert: "You are not authorized to delete this upload." }
      format.json { render json: { success: false, error: "You are not authorized to delete this upload." }, status: :forbidden }
    end
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    respond_to do |format|
      format.html { redirect_back fallback_location: uploads_path, alert: "Delete failed. (Error ID: #{event&.event_id})" }
      format.json { render json: { success: false, error: "Delete failed: #{e.message}" }, status: :internal_server_error }
    end
  end

  def destroy_batch
    ids = Array(params[:ids]).reject(&:blank?)

    if ids.empty?
      respond_to do |format|
        format.html { redirect_to uploads_path, alert: "No files selected." }
        format.json { render json: { success: false, error: "No files selected." }, status: :unprocessable_entity }
      end
      return
    end

    # Resolve ownership for every id before deleting anything, so a selection
    # containing ids the user doesn't own can't delete half the batch silently.
    uploads = current_user.uploads.where(id: ids).includes(:blob)
    missing = ids - uploads.map(&:id)

    if uploads.empty?
      respond_to do |format|
        format.html { redirect_to uploads_path, alert: "None of the selected files could be found." }
        format.json { render json: { success: false, error: "None of the selected files could be found." }, status: :not_found }
      end
      return
    end

    count = uploads.size
    deleted_ids = uploads.map(&:id)
    uploads.destroy_all
    invalidate_activity_ribbon_cache

    notice = "Deleted #{count} #{'file'.pluralize(count)}."
    notice += " #{missing.size} #{'file'.pluralize(missing.size)} could not be found and #{missing.size == 1 ? 'was' : 'were'} skipped." if missing.any?

    respond_to do |format|
      format.html { redirect_to uploads_path, notice: notice }
      format.json { render json: { success: true, notice: notice, count: count, ids: deleted_ids } }
    end
  rescue StandardError => e
    event = Sentry.capture_exception(e)
    respond_to do |format|
      format.html { redirect_to uploads_path, alert: "Delete failed: #{e.message}" }
      format.json { render json: { success: false, error: "Delete failed: #{e.message}" }, status: :internal_server_error }
    end
  end

  private

  def invalidate_activity_ribbon_cache
    return unless current_user.respond_to?(:id)

    user_id = current_user.id
    Rails.cache.delete(["user_activity_ribbon_html", user_id, Date.current.to_s, 2])
    Rails.cache.delete(["user_activity_ribbon_html", user_id, Date.current.to_s, 1])
  end

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
