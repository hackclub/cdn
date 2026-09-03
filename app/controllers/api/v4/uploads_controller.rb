# frozen_string_literal: true

module API
  module V4
    class UploadsController < ApplicationController
      before_action :check_quota, only: [ :create, :create_from_url ]

      rate_limit to: 10, within: 1.minute, only: :create_from_url,
        by: -> { current_user&.id },
        with: -> { render json: { error: "Too many requests" }, status: :too_many_requests }

      # POST /api/v4/upload
      def create
        file = params[:file]

        unless file.present?
          render_missing_parameter(
            "file",
            error: "Missing file parameter",
            hint: "Send the file as multipart/form-data under the `file` field, e.g. `curl -F \"file=@photo.jpg\"`."
          )
          return
        end

        content_type = Marcel::MimeType.for(file.tempfile, name: file.original_filename) || file.content_type || "application/octet-stream"
        content_type = Upload.normalize_content_type(content_type)

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
        render_json_error(
          error: "Upload failed: #{e.message}",
          code: :upload_failed,
          status: :unprocessable_entity,
          message: "The file could not be stored: #{e.message}",
          hint: "Check the file is readable and under your per-file size limit, then retry. See https://#{JSONErrorResponses.canonical_host}/docs/quotas."
        )
      end

      # POST /api/v4/uploads (batch)
      def create_batch
        files = batch_files

        if files.empty?
          render_missing_parameter(
            "files",
            error: "Missing files parameter",
            hint: "Send each file as multipart/form-data under a repeated `files` (or `files[]`) field, e.g. `curl -F \"files=@a.png\" -F \"files=@b.png\"`."
          )
          return
        end

        if files.size > BatchUploadService::MAX_FILES_PER_BATCH
          render_json_error(
            error: "Too many files",
            code: :too_many_files,
            status: :bad_request,
            message: "Maximum #{BatchUploadService::MAX_FILES_PER_BATCH} files per batch, got #{files.size}.",
            hint: "Split the request into batches of #{BatchUploadService::MAX_FILES_PER_BATCH} files or fewer.",
            detail: "Maximum #{BatchUploadService::MAX_FILES_PER_BATCH} files per batch, got #{files.size}"
          )
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
          render_missing_parameter(
            "url",
            error: "Missing url parameter",
            hint: "POST JSON like {\"url\":\"https://example.com/image.jpg\"} with `Content-Type: application/json`."
          )
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
            render_quota_error(usage)
            return
          end
        end

        render json: upload_json(upload), status: :created
      rescue => e
        render_json_error(
          error: "Upload failed: #{e.message}",
          code: :upload_failed,
          status: :unprocessable_entity,
          message: "The source URL could not be fetched or stored: #{e.message}",
          hint: "Confirm the URL is publicly reachable (or pass `X-Download-Authorization`), returns a file, and is under your per-file size limit."
        )
      end

      # DELETE /api/v4/upload/:id
      def destroy
        upload = current_user.uploads.find(params[:id])
        upload.destroy!

        render json: { id: upload.id, deleted: true }, status: :ok
      end

      # PATCH /api/v4/uploads/:id/rename
      def rename
        upload = current_user.uploads.find(params[:id])
        new_filename = params[:filename].to_s.strip

        if new_filename.blank?
          render_missing_parameter(
            "filename",
            error: "Missing filename parameter",
            hint: "Send JSON like {\"filename\":\"new-name.png\"}. Keep the extension so the CDN serves the right content type."
          )
          return
        end

        upload.rename!(new_filename)
        render json: upload_json(upload)
      rescue ActiveRecord::RecordNotFound
        render_json_error(
          error: "Upload not found",
          code: :upload_not_found,
          status: :not_found,
          message: "No upload with that ID belongs to this API key's owner.",
          hint: "List your uploads in the dashboard, or check the ID from the original upload response."
        )
      rescue => e
        render_json_error(
          error: "Rename failed: #{e.message}",
          code: :rename_failed,
          status: :unprocessable_entity,
          message: "The upload could not be renamed: #{e.message}",
          hint: "Filenames must be non-blank and are sanitized before storage. Renaming changes the CDN URL."
        )
      end

      # DELETE /api/v4/uploads/batch
      def destroy_batch
        ids = Array(params[:ids]).reject(&:blank?)

        if ids.empty?
          render_missing_parameter(
            "ids[]",
            error: "Missing ids[] parameter",
            hint: "Send JSON like {\"ids\":[\"<upload-id>\",\"<upload-id>\"]}."
          )
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

      # Accepts every shape a multipart client might use for the batch field:
      # repeated `files`, repeated `files[]`, or a single `files` part. Generated
      # OpenAPI clients send the property name verbatim, so `files` must work.
      def batch_files
        raw = params[:files]
        raw = params["files[]"] if raw.blank?

        files = raw.is_a?(Array) ? raw : [ raw ]
        files.reject(&:blank?)
      end

      def render_missing_parameter(name, error:, hint:)
        render_json_error(
          error: error,
          code: :missing_parameter,
          status: :bad_request,
          message: "Required parameter `#{name}` is missing or blank.",
          hint: hint,
          parameter: name
        )
      end

      def check_quota
        # For direct uploads, check file size before processing
        if params[:file].present?
          file_size = params[:file].size
          quota_service = QuotaService.new(current_user)
          policy = quota_service.current_policy

          # Check per-file size limit
          if file_size > policy.max_file_size
            usage = quota_service.current_usage
            render_quota_error(
              usage,
              "File size exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file",
              code: :file_too_large
            )
            return
          end

          # Check if upload would exceed total storage quota
          unless quota_service.can_upload?(file_size)
            usage = quota_service.current_usage
            render_quota_error(usage)
            nil
          end
        end
        # For URL uploads, quota is checked after download in create_from_url
        # For batch uploads, quota is handled by BatchUploadService
      end

      def render_quota_error(usage, custom_message = nil, code: :quota_exceeded)
        render_json_error(
          error: custom_message || "Storage quota exceeded",
          code: code,
          status: :payment_required,
          message: custom_message || "This upload would exceed the storage quota for your account (#{usage[:policy]} tier).",
          hint: "Delete files you no longer need, or ask for a higher tier. See https://#{JSONErrorResponses.canonical_host}/docs/quotas.",
          quota: {
            storage_used: usage[:storage_used],
            storage_limit: usage[:storage_limit],
            quota_tier: usage[:policy],
            percentage_used: usage[:percentage_used]
          }
        )
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
