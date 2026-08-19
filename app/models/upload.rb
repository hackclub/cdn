# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "socket"

class Upload < ApplicationRecord
  include PgSearch::Model

  # UUID v7 primary key (automatic via migration)

  belongs_to :user
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  after_destroy :purge_blob
  after_destroy :purge_cdn_cache

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

  # Ensure text content types include charset=utf-8 so browsers
  # don't fall back to ISO-8859-1 and mangle unicode
  def self.normalize_content_type(content_type)
    if content_type&.start_with?("text/") && !content_type.include?("charset")
      "#{content_type}; charset=utf-8"
    else
      content_type
    end
  end

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

  # Direct URL to public R2 bucket
  def assets_url
    host = ENV.fetch("CDN_ASSETS_HOST", "cdn.hackclub-assets.com")
    "https://#{host}/#{blob.key}"
  end

  # Get CDN URL (uses external uploads controller)
  def cdn_url
    Rails.application.routes.url_helpers.external_upload_url(
      id:,
      filename:,
      host: ENV["CDN_HOST"] || "cdn.hackclub.com"
    )
  end

  # Rename the display filename (storage key stays the same)
  def rename!(new_filename)
    sanitized = ActiveStorage::Filename.new(new_filename).sanitized

    # Preserve the original extension if the user didn't provide one
    original_ext = File.extname(blob.filename.to_s)
    new_ext = File.extname(sanitized)
    sanitized = "#{sanitized}#{original_ext}" if new_ext.blank? && original_ext.present?

    blob.update!(filename: sanitized)
  end

  MAX_FETCH_REDIRECTS = 5

  BLOCKED_FETCH_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 64:ff9b::/96 fc00::/7 fe80::/10
  ].map { |range| IPAddr.new(range) }.freeze

  def self.resolve_fetchable_addresses!(uri)
    unless %w[http https].include?(uri.scheme&.downcase)
      raise ArgumentError, "URL scheme must be http or https."
    end

    host = uri.hostname
    raise ArgumentError, "Invalid host" if host.blank?

    port = uri.port || uri.default_port

    addresses =
      begin
        Addrinfo.getaddrinfo(host, port, nil, :STREAM).map(&:ip_address).uniq
      rescue SocketError
        []
      end
    raise ArgumentError, "Couldn't resolve host." if addresses.empty?

    addresses.each do |address|
      raise ArgumentError, "IP address not allowed" if blocked_fetch_address?(address)
    end

    addresses
  end

  def self.fetch_public_url!(url, max_bytes:, authorization: nil)
    uri = URI.parse(url)
    token = authorization
    hops = 0

    loop do
      address = resolve_fetchable_addresses!(uri).first
      result = perform_fetch(uri, address, token, max_bytes)
      return result unless result.key?(:location)

      hops += 1
      raise "Failed to download: too many redirects" if hops > MAX_FETCH_REDIRECTS
      raise "Failed to download: redirect without a location" if result[:location].blank?

      following = uri.merge(result[:location])
      token = nil unless same_fetch_origin?(uri, following)
      uri = following
    end
  end

  # Create upload from URL (for API/rescue operations)
  def self.create_from_url(url, user:, provenance:, original_url: nil, authorization: nil, filename: nil)
    quota_service = QuotaService.new(user)
    policy = quota_service.current_policy
    remaining_storage = policy.max_total_storage - user.total_storage_bytes
    raise "File would exceed storage quota" if remaining_storage <= 0

    fetched = fetch_public_url!(
      url,
      max_bytes: [ policy.max_file_size, remaining_storage ].min,
      authorization: authorization
    )

    filename ||= extract_filename_from_url(url)
    body = fetched[:body]
    content_type = Marcel::MimeType.for(StringIO.new(body), name: filename) ||
                   fetched[:content_type] ||
                   "application/octet-stream"
    content_type = normalize_content_type(content_type)

    # Pre-generate upload ID for predictable storage path
    upload_id = SecureRandom.uuid_v7
    sanitized_filename = ActiveStorage::Filename.new(filename).sanitized
    storage_key = "#{upload_id}/#{sanitized_filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type,
      identify: false,
      key: storage_key
    )

    create!(
      id: upload_id,
      user: user,
      blob: blob,
      provenance: provenance,
      original_url: original_url
    )
  end

  class << self
    private

    def blocked_fetch_address?(address)
      ip = IPAddr.new(address.split("%").first)
      ip = ip.native if ip.ipv6? && ip.ipv4_mapped?
      BLOCKED_FETCH_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def perform_fetch(uri, address, authorization, max_bytes)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.ipaddr = address
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 30
      http.read_timeout = 120

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = authorization if authorization.present?

      http.start do |connection|
        connection.request(request) do |response|
          return { location: response["location"] } if response.is_a?(Net::HTTPRedirection)
          raise "Failed to download: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          body = +""
          response.read_body do |chunk|
            body << chunk
            if body.bytesize > max_bytes
              raise "File too large: exceeds limit of " \
                    "#{ActiveSupport::NumberHelper.number_to_human_size(max_bytes)}"
            end
          end

          return { body: body, content_type: response["content-type"] }
        end
      end
    end

    def same_fetch_origin?(from, to)
      [ from.scheme, from.hostname, from.port ] == [ to.scheme, to.hostname, to.port ]
    end

    def extract_filename_from_url(url)
      File.basename(URI.parse(url).path).presence || "download"
    end
  end

  private

  def purge_blob
    blob.purge
  rescue Aws::S3::Errors::NoSuchKey
    Rails.logger.info("Blob #{blob.key} already deleted from S3, skipping purge")
  end

  def purge_cdn_cache = PurgeCloudflareCacheJob.perform_later(assets_url)
end
