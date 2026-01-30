# frozen_string_literal: true

class CDNStatsService
  CACHE_KEY_GLOBAL = "cdn:stats:global"
  CACHE_DURATION = 5.minutes

  # Global stats (cached) - for logged-out users
  def self.global_stats
    Rails.cache.fetch(CACHE_KEY_GLOBAL, expires_in: CACHE_DURATION) do
      calculate_global_stats
    end
  end

  # Force refresh global stats (called by background job)
  def self.refresh_global_stats!
    Rails.cache.delete(CACHE_KEY_GLOBAL)
    global_stats
  end

  # User stats (live) - for logged-in users
  def self.user_stats(user)
    quota_service = QuotaService.new(user)
    usage = quota_service.current_usage
    policy = quota_service.current_policy

    used = usage[:storage_used]
    max = usage[:storage_limit]
    percentage = usage[:percentage_used]
    available = [max - used, 0].max

    {
      total_files: user.total_files,
      total_storage: used,
      storage_formatted: user.total_storage_formatted,
      files_today: user.uploads.today.count,
      files_this_week: user.uploads.this_week.count,
      recent_uploads: user.uploads.includes(:blob).recent.limit(5),
      quota: {
        policy: usage[:policy],
        storage_limit: max,
        available: available,
        percentage_used: percentage,
        at_warning: usage[:at_warning],
        over_quota: usage[:over_quota]
      }
    }
  end

  private

  def self.calculate_global_stats
    total_files = Upload.count
    total_storage_bytes = Upload.joins(:blob).sum('active_storage_blobs.byte_size')
    total_users = User.joins(:uploads).distinct.count

    {
      total_files: total_files,
      total_storage_bytes: total_storage_bytes,
      storage_formatted: ActiveSupport::NumberHelper.number_to_human_size(total_storage_bytes),
      total_users: total_users,
      files_today: Upload.today.count,
      files_this_week: Upload.this_week.count
    }
  end
end
