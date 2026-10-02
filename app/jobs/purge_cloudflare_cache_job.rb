# frozen_string_literal: true

class PurgeCloudflareCacheJob < ApplicationJob
  class ConfigurationError < StandardError; end

  class PurgeFailedError < StandardError; end

  queue_as :default

  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 5
  retry_on PurgeFailedError, wait: :polynomially_longer, attempts: 5

  def perform(urls)
    urls = Array(urls).map { |url| url.to_s.strip }.reject(&:blank?).uniq
    return if urls.empty?

    api_token = ENV["CLOUDFLARE_API_TOKEN"].presence
    if api_token.nil?
      return if Rails.env.local?

      raise ConfigurationError,
        "CLOUDFLARE_API_TOKEN is not set!! cache purging will fail!"
    end

    zone_ids = zone_ids_by_host

    urls.group_by { |url| URI.parse(url).host }.each do |host, host_urls|
      zone_id = zone_ids[host]

      if zone_id.blank?
        raise ConfigurationError,
          "No Cloudflare zone id configured for #{host}, so #{host_urls.size} " \
          "URL(s) cannot be purged (configured hosts: #{zone_ids.keys.join(', ')})"
      end

      host_urls.each_slice(30) do |slice|
        purge!(zone_id: zone_id, files: slice, api_token: api_token)
      end
    end
  end

  private

  # Host => zone id. Both zones are required: purging only one leaves the other
  # serving the deleted file.
  def zone_ids_by_host
    mapping = {
      CDNHost.host => ENV["CLOUDFLARE_ZONE_ID"].presence,
      CDNHost.assets_host => ENV["CLOUDFLARE_ASSETS_ZONE_ID"].presence
    }

    configured = mapping.values.compact
    if mapping.size > 1 && configured.uniq.size < configured.size
      raise ConfigurationError,
        "CLOUDFLARE_ZONE_ID and CLOUDFLARE_ASSETS_ZONE_ID are set to the same zone, " \
        "but #{mapping.keys.join(' and ')} are in different Cloudflare zones"
    end

    mapping
  end

  def purge!(zone_id:, files:, api_token:)
    response = connection.post("/client/v4/zones/#{zone_id}/purge_cache") do |req|
      req.headers["Authorization"] = "Bearer #{api_token}"
      req.body = { files: files }
    end

    body = response.body
    return if response.success? && body.is_a?(Hash) && body["success"]

    raise PurgeFailedError,
      "Cloudflare cache purge failed for zone #{zone_id} " \
      "(HTTP #{response.status}, #{files.size} URL(s)): #{body.inspect}"
  end

  def connection
    @connection ||= Faraday.new(url: "https://api.cloudflare.com") do |f|
      f.request :json
      f.response :json
      f.adapter :net_http
    end
  end
end
