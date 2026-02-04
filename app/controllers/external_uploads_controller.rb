# frozen_string_literal: true

class ExternalUploadsController < ApplicationController
  skip_before_action :require_authentication!

  def show
    upload = Upload.includes(:blob).find(params[:id])
    expires_in ActiveStorage.service_urls_expire_in, public: true
    redirect_to upload.blob.url(disposition: :inline), allow_other_host: true
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def rescue
    url = params[:url]

    if url.blank?
      head :bad_request
      return
    end

    upload = Upload.includes(:blob).find_by(original_url: url)

    if upload
      expires_in ActiveStorage.service_urls_expire_in, public: true
      redirect_to upload.cdn_url, allow_other_host: true
    else
      render_not_found_response(url)
    end
  end

  private

  def render_not_found_response(url)
    if url.match?(/\.(png|jpe?g)$/i)
      render_error_image
    else
      head :not_found
    end
  end

  def render_error_image
    svg = <<~SVG
      <svg width="800" height="400" xmlns="http://www.w3.org/2000/svg">
        <rect width="800" height="400" fill="#FBECED"/>
        <circle cx="400" cy="140" r="40" fill="#EC3750" opacity="0.2"/>
        <text x="400" y="150" font-family="Phantom Sans, system-ui, -apple-system, sans-serif" font-size="32" fill="#EC3750" text-anchor="middle" font-weight="700">
          404
        </text>
        <text x="400" y="210" font-family="Phantom Sans, system-ui, -apple-system, sans-serif" font-size="20" fill="#1F2D3D" text-anchor="middle" font-weight="600">
          Original URL not found in CDN
        </text>
        <text x="400" y="250" font-family="Phantom Sans, system-ui, -apple-system, sans-serif" font-size="14" fill="#3C4858" text-anchor="middle">
          This file hasn't been uploaded or rescued yet.
        </text>
        <text x="400" y="280" font-family="Phantom Sans, system-ui, -apple-system, sans-serif" font-size="14" fill="#3C4858" text-anchor="middle">
          Try uploading it at cdn.hackclub.com
        </text>
      </svg>
    SVG

    render inline: svg, content_type: "image/svg+xml"
  end
end
