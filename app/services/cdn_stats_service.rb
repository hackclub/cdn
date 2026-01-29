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
    {
      total_files: user.total_files,
      total_storage: user.total_storage_gb,
      storage_formatted: "#{user.total_storage_gb} GB",
      files_today: user.uploads.today.count,
      files_this_week: user.uploads.this_week.count,
      recent_uploads: user.uploads.includes(:blob).recent.limit(5)
    }
  end

  private

  def self.calculate_global_stats
    total_files = Upload.count
    total_storage_bytes = Upload.joins(:blob).sum('active_storage_blobs.byte_size')
    total_storage_gb = (total_storage_bytes / 1.gigabyte.to_f).round(2)
    total_users = User.joins(:uploads).distinct.count

    {
      total_files: total_files,
      total_storage_gb: total_storage_gb,
      storage_formatted: "#{total_storage_gb} GB",
      total_users: total_users,
      files_today: Upload.today.count,
      files_this_week: Upload.this_week.count
    }
  end
end
