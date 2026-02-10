# frozen_string_literal: true

module API
  module V4
    class UploadsController < ApplicationController
      before_action :check_quota, only: [ :create, :create_from_url ]

      # POST /api/v4/upload
      def create
        file = params[:file]

        unless file.present?
          render json: { error: "Missing file parameter" }, status: :bad_request
          return
        end

        content_type = Marcel::MimeType.for(file.tempfile, name: file.original_filename) || file.content_type || "application/octet-stream"

        # Pre-gen upload ID for predictable storage path
        upload_id = SecureRandom.uuid_v7
        sanitized_filename = ActiveStorage::Filename.new(file.original_filename).sanitized
        storage_key = "#{upload_id}/#{sanitized_filename}"

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file.tempfile,
          filename: file.original_filename,
          content_type: content_type,
          key: storage_key
        )

        upload = current_user.uploads.create!(id: upload_id, blob: blob, provenance: :api)

        render json: upload_json(upload), status: :created
      rescue => e
        render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
      end

      # POST /api/v4/uploads (batch)
      def create_batch
        files = params[:files]

        unless files.present? && files.is_a?(Array)
          render json: { error: "Missing files[] parameter" }, status: :bad_request
          return
        end

        if files.size > BatchUploadService::MAX_FILES_PER_BATCH
          render json: {
            error: "Too many files",
            detail: "Maximum #{BatchUploadService::MAX_FILES_PER_BATCH} files per batch, got #{files.size}"
          }, status: :bad_request
          return
        end

        service = BatchUploadService.new(user: current_user, provenance: :api)
        result = service.process_files(files)

        response = {
          uploads: result.uploads.map { |u| upload_json(u) },
          failed: result.failed.map { |f| { filename: f.filename, reason: f.reason } }
        }

        status = result.uploads.any? ? :created : :unprocessable_entity
        render json: response, status: status
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

        # Check quota after download (URL upload size unknown beforehand)
        quota_service = QuotaService.new(current_user)
        unless quota_service.can_upload?(0)
          if current_user.total_storage_bytes > quota_service.current_policy.max_total_storage
            upload.destroy!
            usage = quota_service.current_usage
            render json: quota_error_json(usage), status: :payment_required
            return
          end
        end

        render json: upload_json(upload), status: :created
      rescue => e
        render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
      end

      # PATCH /api/v4/uploads/:id/rename
      def rename
        upload = current_user.uploads.find(params[:id])
        new_filename = params[:filename].to_s.strip

        if new_filename.blank?
          render json: { error: "Missing filename parameter" }, status: :bad_request
          return
        end

        upload.rename!(new_filename)
        render json: upload_json(upload)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Upload not found" }, status: :not_found
      rescue => e
        render json: { error: "Rename failed: #{e.message}" }, status: :unprocessable_entity
      end

      # DELETE /api/v4/uploads/batch
      def destroy_batch
        ids = Array(params[:ids]).reject(&:blank?)

        if ids.empty?
          render json: { error: "Missing ids[] parameter" }, status: :bad_request
          return
        end

        uploads = current_user.uploads.where(id: ids).includes(:blob)
        found_ids = uploads.map(&:id)
        not_found_ids = ids - found_ids

        deleted = uploads.map { |u| { id: u.id, filename: u.filename.to_s } }
        uploads.destroy_all

        response = { deleted: deleted }
        response[:not_found] = not_found_ids if not_found_ids.any?

        render json: response, status: :ok
      end

      private

      def check_quota
        # For direct uploads, check file size before processing
        if params[:file].present?
          file_size = params[:file].size
          quota_service = QuotaService.new(current_user)
          policy = quota_service.current_policy

          # Check per-file size limit
          if file_size > policy.max_file_size
            usage = quota_service.current_usage
            render json: quota_error_json(usage, "File size exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file"), status: :payment_required
            return
          end

          # Check if upload would exceed total storage quota
          unless quota_service.can_upload?(file_size)
            usage = quota_service.current_usage
            render json: quota_error_json(usage), status: :payment_required
            nil
          end
        end
        # For URL uploads, quota is checked after download in create_from_url
        # For batch uploads, quota is handled by BatchUploadService
      end

      def quota_error_json(usage, custom_message = nil)
        {
          error: custom_message || "Storage quota exceeded",
          quota: {
            storage_used: usage[:storage_used],
            storage_limit: usage[:storage_limit],
            quota_tier: usage[:policy],
            percentage_used: usage[:percentage_used]
          }
        }
      end

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
