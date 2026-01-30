# frozen_string_literal: true

class QuotaService
  WARNING_THRESHOLD_PERCENTAGE = 80

  def initialize(user)
    @user = user
  end

  # Returns the applicable Quota::Policy for the user
  # Checks HCA if quota_policy is NULL, upgrades to verified if confirmed
  def current_policy
    if @user.quota_policy.present?
      # User has explicit policy set - use it
      Quota.policy(@user.quota_policy.to_sym)
    else
      # No policy set - check HCA verification
      if hca_verified?
        # User is verified - upgrade them permanently
        @user.update_column(:quota_policy, "verified")
        Quota.policy(:verified)
      else
        # Not verified - use unverified tier (don't set field)
        Quota.policy(:unverified)
      end
    end
  rescue KeyError
    # Invalid policy slug - fall back to unverified
    Quota.policy(:unverified)
  end

  # Returns hash with storage info, policy, and flags
  def current_usage
    policy = current_policy
    used = @user.total_storage_bytes
    max = policy.max_total_storage
    percentage = percentage_used

    {
      storage_used: used,
      storage_limit: max,
      policy: policy.slug.to_s,
      percentage_used: percentage,
      at_warning: at_warning?,
      over_quota: over_quota?
    }
  end

  # Validates if upload is allowed based on file size and total storage
  def can_upload?(file_size)
    policy = current_policy

    # Check file size against per-file limit
    return false if file_size > policy.max_file_size

    # Check total storage after upload
    total_after = @user.total_storage_bytes + file_size
    return false if total_after > policy.max_total_storage

    true
  end

  # Boolean if storage exceeded
  def over_quota?
    @user.total_storage_bytes >= current_policy.max_total_storage
  end

  # Boolean if >= 80% used
  def at_warning?
    percentage_used >= WARNING_THRESHOLD_PERCENTAGE
  end

  # Calculate usage percentage
  def percentage_used
    max = current_policy.max_total_storage
    return 0 if max.zero?

    ((@user.total_storage_bytes.to_f / max) * 100).round(2)
  end

  # Check HCA and upgrade to verified if confirmed
  # Returns true if verification successful, false otherwise
  def check_and_upgrade_verification!
    return true if @user.quota_policy.present? # Already has policy set

    if hca_verified?
      @user.update_column(:quota_policy, "verified")
      true
    else
      false
    end
  rescue Faraday::Error => e
    Rails.logger.warn "HCA verification check failed for user #{@user.id}: #{e.message}"
    false
  end

  private

  # Check if user is verified via HCA
  def hca_verified?
    return false unless @user.hca_access_token.present?
    return false unless @user.hca_id.present?

    hca = HCAService.new(@user.hca_access_token)
    response = hca.check_verification(idv_id: @user.hca_id)
    response[:result] == "verified_eligible"
  rescue Faraday::Error, ArgumentError => e
    Rails.logger.warn "HCA API error for user #{@user.id}: #{e.message}"
    false
  end
end
