module Privacy
  class Eraser
    TABLES = %w[users api_keys uploads active_storage_attachments active_storage_variant_records active_storage_blobs].freeze

    def initialize(claims)
      @claims = claims
      @subject = claims.fetch("subject")
      @dry_run = claims.fetch("dry_run")
    end

    def call(action)
      result = { "request_id" => @claims.fetch("request_id"), "found" => false,
        "dry_run" => @dry_run, "deleted" => TABLES.index_with { 0 }, "retained" => [] }
      if action == "export"
        # Reads only, apart from replay bookkeeping performed by the controller.
        users = matched_users.to_a
        prepare(users)
        jobs = @queue.plan(lock: false)
        return result if users.empty? && jobs.empty?
        result["found"] = true
        result["deleted"] = database_counts.merge(@queue.counts(jobs))
        result["retained"] = retained
        return result
      end

      User.transaction(requires_new: true) do
        slack_ids = matched_users.pluck(:slack_id) + [ @subject["slack_id"] ]
        SubjectLock.acquire!(slack_ids)
        users = matched_users.order(:id).lock.to_a
        prepare(users, lock: true)
        result["retained"] = retained
        check_shared_keys!
        files = Files.new(@blobs, @uploads)
        @queue.transaction do
          jobs = @queue.plan(lock: true)
          next if users.empty? && jobs.empty?
          result["found"] = true
          # Use delete_all to avoid Upload's storage and enqueue callbacks. Every
          # DB mutation below is executed for dry runs too, then rolled back.
          queue_counts = @queue.delete!(jobs)
          result["deleted"] = {
            "active_storage_attachments" => ActiveStorage::Attachment.where(id: @attachment_ids).delete_all,
            "active_storage_variant_records" => ActiveStorage::VariantRecord.where(id: @variant_ids).delete_all,
            "uploads" => Upload.where(id: @uploads.map(&:id)).delete_all,
            "api_keys" => APIKey.where(user_id: @user_ids).delete_all,
            "active_storage_blobs" => ActiveStorage::Blob.where(id: @blobs.map(&:id)).delete_all,
            "users" => User.where(id: @user_ids).delete_all
          }.merge(queue_counts)
          files.delete! unless @dry_run
          raise ActiveRecord::Rollback if @dry_run
        end
        raise ActiveRecord::Rollback if @dry_run
      end
      result
    end

    private

    def matched_users
      scope = User.none
      emails = @subject.fetch("emails").map(&:downcase)
      scope = scope.or(User.where("LOWER(email) IN (?)", emails)) if emails.any?
      scope = scope.or(User.where(slack_id: @subject["slack_id"])) if @subject["slack_id"].present?
      scope = scope.or(User.where(hca_id: @subject["identity_id"])) if @subject["identity_id"].present?
      scope
    end

    def prepare(users, lock: false)
      @user_ids = users.map(&:id)
      uploads = Upload.where(user_id: @user_ids).order(:id)
      @uploads = (lock ? uploads.lock : uploads).to_a
      attachments = ActiveStorage::Attachment.where(record_type: "User", record_id: @user_ids)
        .or(ActiveStorage::Attachment.where(record_type: "Upload", record_id: @uploads.map(&:id)))
      root_attachment_ids = attachments.pluck(:id)
      candidates = (@uploads.map(&:blob_id) + attachments.pluck(:blob_id)).uniq
      all_ids = candidates.dup
      variant_ids = []
      attachment_ids = root_attachment_ids.dup
      # Include tracked variant image blobs, which themselves may have variants.
      loop do
        variants = ActiveStorage::VariantRecord.where(blob_id: candidates)
        new_variants = variants.pluck(:id) - variant_ids
        break if new_variants.empty?
        variant_ids.concat(new_variants)
        images = ActiveStorage::Attachment.where(record_type: "ActiveStorage::VariantRecord", record_id: new_variants)
        attachment_ids |= images.pluck(:id)
        candidates = images.pluck(:blob_id) - all_ids
        all_ids |= candidates
      end
      # Keep any blob referenced outside this deletion, and its variant tree.
      kept = []
      loop do
        shared = Upload.where(blob_id: all_ids).where.not(id: @uploads.map(&:id)).pluck(:blob_id)
        shared |= ActiveStorage::Attachment.where(blob_id: all_ids).where.not(id: attachment_ids).pluck(:blob_id)
        shared |= kept
        break if shared.sort == kept.sort
        kept = shared
        preserved_variants = ActiveStorage::VariantRecord.where(blob_id: kept).pluck(:id)
        preserved_images = ActiveStorage::Attachment.where(record_type: "ActiveStorage::VariantRecord", record_id: preserved_variants).pluck(:id)
        variant_ids -= preserved_variants
        attachment_ids -= preserved_images
      end
      blobs = ActiveStorage::Blob.where(id: all_ids - kept).order(:id)
      @blobs = (lock ? blobs.lock : blobs).to_a
      @kept_blob_count = kept.size
      @attachment_ids, @variant_ids = attachment_ids, variant_ids
      @queue = QueuedData.new(@subject, users, @uploads)
    end

    def database_counts
      { "users" => @user_ids.size, "api_keys" => APIKey.where(user_id: @user_ids).count,
        "uploads" => @uploads.size, "active_storage_attachments" => @attachment_ids.size,
        "active_storage_variant_records" => @variant_ids.size, "active_storage_blobs" => @blobs.size }
    end

    def retained
      return [] if @kept_blob_count.zero?
      [ { "type" => "shared upload blobs", "count" => @kept_blob_count,
        "reason" => "Other accounts or surviving attachments use these files; the deleted account's upload and attachment references are removed." } ]
    end

    def check_shared_keys!
      protected_ids = ENV.fetch("PRIVACY_SHARED_API_KEY_IDS", "").split(",").map(&:strip)
      if APIKey.active.where(user_id: @user_ids, id: protected_ids).exists?
        raise Error.new("manual_review_required", 409)
      end
    end
  end
end
