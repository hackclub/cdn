# frozen_string_literal: true

# Single source of truth for the CDN's public hostname. CDN_HOST is documented
# as a bare hostname, but some deployments store a full https:// URL there.
# Normalize it so URL builders that add their own scheme never emit
# "https://https://cdn.hackclub.com".
module CDNHost
  DEFAULT_HOST = "cdn.hackclub.com"

  module_function

  def host
    raw = ENV["CDN_HOST"].presence || DEFAULT_HOST
    raw.sub(%r{\Ahttps?://}i, "").sub(%r{/+\z}, "")
  end

  def base_url = "https://#{host}"
end
