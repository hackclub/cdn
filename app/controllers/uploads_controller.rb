# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :set_upload, only: [:destroy]

  def index
    @uploads = current_user.uploads.includes(:blob).recent

    if params[:query].present?
      @uploads = @uploads.search_by_filename(params[:query])
    end

    @uploads = @uploads.page(params[:page]).per(50)
  end

  def new
  end

  def create
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_to new_upload_path, alert: "Please select a file to upload."
      return
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_file.tempfile,
      filename: uploaded_file.original_filename,
      content_type: uploaded_file.content_type
    )

    @upload = current_user.uploads.create!(
      blob: blob,
      provenance: :web
    )

    redirect_to uploads_path, notice: "File uploaded successfully!"
  rescue StandardError => e
    redirect_to new_upload_path, alert: "Upload failed: #{e.message}"
  end

  def destroy
    authorize @upload

    @upload.destroy!
    redirect_to uploads_path, notice: "Upload deleted successfully."
  rescue Pundit::NotAuthorizedError
    redirect_to uploads_path, alert: "You are not authorized to delete this upload."
  end

  private

  def set_upload
    @upload = Upload.find(params[:id])
  end
end
