# frozen_string_literal: true

require "csv"
require "ruby-progressbar"

namespace :import do
  desc "Import files from Slack using a CSV with slack_file_url and slack_user_id"
  task slack_files: :environment do
    # Set URL options for ActiveStorage in rake context
    ActiveStorage::Current.url_options = { host: ENV.fetch("CDN_HOST", "cdn.hackclub.com"), protocol: "https" }
    csv_path = ENV.fetch("CSV_PATH", "files_with_slack_url.csv")
    slack_token = ENV.fetch("SLACK_TOKEN") { raise "SLACK_TOKEN (xoxp-...) is required" }
    thread_count = ENV.fetch("THREADS", 10).to_i
    dry_run = ENV["DRY_RUN"] == "true"

    unless File.exist?(csv_path)
      puts "CSV file not found: #{csv_path}"
      exit 1
    end

    rows = CSV.read(csv_path, headers: true)
    limit = ENV.fetch("LIMIT", rows.size).to_i
    rows = rows.first(limit)
    total = rows.size

    puts "Found #{total} files to import#{' (DRY RUN)' if dry_run}"
    puts "Threads: #{thread_count}"
    puts

    progressbar = ProgressBar.create(
      total: total,
      format: "%t |%B| %c/%C (%p%%) %e",
      title: "Importing"
    )

    stats = {
      success: Concurrent::AtomicFixnum.new(0),
      skipped: Concurrent::AtomicFixnum.new(0),
      failed: Concurrent::AtomicFixnum.new(0)
    }
    errors = Concurrent::Array.new
    user_cache = Concurrent::Hash.new
    user_cache_mutex = Mutex.new

    # Pre-cache existing original_urls to avoid N+1 queries
    puts "Loading existing uploads..."
    existing_urls = Upload.where(original_url: rows.map { |r| r["original_url"] }.compact)
                          .pluck(:original_url)
                          .to_set
    puts "Found #{existing_urls.size} already imported"

    pool = Concurrent::FixedThreadPool.new(thread_count)

    rows.each do |row|
      pool.post do
        original_url = row["original_url"]
        slack_file_url = row["slack_file_url"]
        slack_user_id = row["slack_user_id"]
        filename = row["filename"]

        begin
          # Skip rows missing required Slack data
          if slack_file_url.blank? || filename.blank?
            stats[:skipped].increment
            next
          end

          if dry_run
            stats[:success].increment
            next
          end

          # Skip if already imported (using pre-cached set)
          if existing_urls.include?(original_url)
            stats[:skipped].increment
            next
          end

          # Thread-safe user lookup/creation with caching
          user = user_cache[slack_user_id]
          unless user
            user_cache_mutex.synchronize do
              user = user_cache[slack_user_id]
              unless user
                user = User.find_or_create_by!(slack_id: slack_user_id) do |u|
                  u.email = nil
                  u.name = "Slack User #{slack_user_id}"
                end
                user_cache[slack_user_id] = user
              end
            end
          end

          # Download from Slack with bearer token (bypasses quota - direct model call)
          Upload.create_from_url(
            slack_file_url,
            user: user,
            provenance: :rescued,
            original_url: original_url,
            authorization: "Bearer #{slack_token}",
            filename: filename
          )

          stats[:success].increment
        rescue => e
          stats[:failed].increment
          errors << { id: row["id"], original_url: original_url, error: e.message }
        ensure
          progressbar.increment
        end
      end
    end

    pool.shutdown
    pool.wait_for_termination

    progressbar.finish

    puts
    puts "Import complete:"
    puts "  ✓ Success: #{stats[:success].value}"
    puts "  ○ Skipped (already exists/missing data): #{stats[:skipped].value}"
    puts "  ✗ Failed: #{stats[:failed].value}"

    if errors.any?
      puts
      puts "Errors (first 20):"
      errors.first(20).each do |err|
        puts "  ID #{err[:id]}: #{err[:error]}"
      end

      # Write full error log
      error_log_path = "import_errors_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
      CSV.open(error_log_path, "w") do |csv|
        csv << %w[id original_url error]
        errors.each { |err| csv << [err[:id], err[:original_url], err[:error]] }
      end
      puts "Full error log written to: #{error_log_path}"
    end
  end
end
