# frozen_string_literal: true

# Single source of truth for the CDN's public hostname. CDN_HOST is documented
# as a bare hostname, but some deployments store a full https:// URL there.
# Normalize it so URL builders that add their own scheme never emit
# "https://https://cdn.hackclub.com".
module CDNHost
  DEFAULT_HOST = "cdn.hackclub.com"
  DEFAULT_ASSETS_HOST = "user-cdn.hackclub-assets.com"

  module_function

  def host
    normalize(ENV["CDN_HOST"].presence || DEFAULT_HOST)
  end

  def assets_host
    normalize(ENV["CDN_ASSETS_HOST"].presence || DEFAULT_ASSETS_HOST)
  end

  def base_url = "https://#{host}"

  def assets_base_url = "https://#{assets_host}"

  def normalize(raw) = raw.to_s.sub(%r{\Ahttps?://}i, "").sub(%r{/+\z}, "")
end
