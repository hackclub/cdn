# frozen_string_literal: true

module MetadataHelper
  SITE_NAME = "Hack Club CDN"
  SITE_DESCRIPTION = "File hosting for Hack Clubbers. Upload files through the dashboard or the HTTP API and get permanent CDN URLs."

  def canonical_host = ENV["CDN_HOST"].presence || "cdn.hackclub.com"
  def canonical_root = "https://#{canonical_host}"
  def canonical_url = content_for(:canonical_url).presence || "#{canonical_root}#{request.path}"
  def page_title = content_for(:title).presence || SITE_NAME
  def page_description = content_for(:description).presence || SITE_DESCRIPTION
  def og_image_url = "#{canonical_root}/icon.png"
end
