# frozen_string_literal: true

module API
  module V4
    class UploadsController < ApplicationController
      # POST /api/v4/upload
      def create
        file = params[:file]

        unless file.present?
          render json: { error: "Missing file parameter" }, status: :bad_request
          return
        end

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file.tempfile,
          filename: file.original_filename,
          content_type: file.content_type
        )

        upload = current_user.uploads.create!(blob: blob, provenance: :api)

        render json: upload_json(upload), status: :created
      rescue => e
        render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
      end

      # POST /api/v4/upload_from_url
      def create_from_url
        url = params[:url]

        unless url.present?
          render json: { error: "Missing url parameter" }, status: :bad_request
          return
        end

        download_auth = request.headers["X-Download-Authorization"]
        upload = Upload.create_from_url(url, user: current_user, provenance: :api, original_url: url, authorization: download_auth)

        render json: upload_json(upload), status: :created
      rescue => e
        render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
      end

      private

      def upload_json(upload)
        {
          id: upload.id,
          filename: upload.filename.to_s,
          size: upload.byte_size,
          content_type: upload.content_type,
          url: upload.cdn_url,
          created_at: upload.created_at.iso8601
        }
      end
    end
  end
end
