# frozen_string_literal: true

require "open-uri"

class Upload < ApplicationRecord
  include PgSearch::Model

  # UUID v7 primary key (automatic via migration)

  belongs_to :user
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  after_destroy :purge_blob

  # Delegate file metadata to blob (no duplication!)
  delegate :filename, :byte_size, :content_type, :checksum, to: :blob

  # Search configuration
  pg_search_scope :search_by_filename,
    associated_against: {
      blob: :filename
    },
    using: {
      tsearch: { prefix: true }
    }

  pg_search_scope :search,
    against: [ :original_url ],
    associated_against: {
      blob: :filename,
      user: [ :email, :name ]
    },
    using: { tsearch: { prefix: true } }

  # Aliases for consistency
  alias_method :file_size, :byte_size
  alias_method :mime_type, :content_type

  # Provenance enum
  enum :provenance, {
    slack: "slack",
    web: "web",
    api: "api",
    rescued: "rescued"
  }, validate: true

  validates :provenance, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :this_week, -> { where("created_at >= ?", Time.zone.now.beginning_of_week) }
  scope :this_month, -> { where("created_at >= ?", Time.zone.now.beginning_of_month) }

  def human_file_size
    ActiveSupport::NumberHelper.number_to_human_size(byte_size)
  end

# direct URL to pub R2 bucket
def assets_url
  host = ENV.fetch("CDN_ASSETS_HOST", "cdn.hackclub-assets.com")
  "https://#{host}/#{id}/#{blob.filename.sanitized}"
end
  # Get CDN URL (uses external uploads controller)
  def cdn_url
    Rails.application.routes.url_helpers.external_upload_url(
      id:,
      filename:,
      host: ENV["CDN_HOST"] || "cdn.hackclub.com"
    )
  end

  # Create upload from URL (for API/rescue operations)
  def self.create_from_url(url, user:, provenance:, original_url: nil, authorization: nil, filename: nil)
    conn = Faraday.new(ssl: { verify: true, verify_mode: OpenSSL::SSL::VERIFY_PEER }) do |f|
      # f.response :follow_redirects, limit: 5
      f.adapter Faraday.default_adapter
    end
    # Disable CRL checking which fails on some servers
    conn.options.open_timeout = 30
    conn.options.timeout = 120

    headers = {}
    headers["Authorization"] = authorization if authorization.present?

    response = conn.get(url, nil, headers)
    if response.status.between?(300, 399)
      location = response.headers["location"]
      raise "Failed to download: #{response.status} redirect to #{location}"
    end
    raise "Failed to download: #{response.status}" unless response.success?

    filename ||= File.basename(URI.parse(url).path)
    body = response.body
    content_type = Marcel::MimeType.for(StringIO.new(body), name: filename) || response.headers["content-type"] || "application/octet-stream"

    # Pre-generate upload ID for predictable storage path
    upload_id = SecureRandom.uuid_v7
    sanitized_filename = ActiveStorage::Filename.new(filename).sanitized
    storage_key = "#{upload_id}/#{sanitized_filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type,
      identify: false
    )

    create!(
      user: user,
      blob: blob,
      provenance: provenance,
      original_url: original_url
    )
  end

  private

  def purge_blob
    blob.purge
  rescue Aws::S3::Errors::NoSuchKey
    Rails.logger.info("Blob #{blob.key} already deleted from S3, skipping purge")
  end
end
