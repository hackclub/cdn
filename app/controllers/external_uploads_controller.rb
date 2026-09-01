# frozen_string_literal: true

class ExternalUploadsController < ApplicationController
  include JSONErrorResponses

  skip_before_action :require_authentication!
  skip_forgery_protection
  before_action :set_cors_headers

  def preflight
    response.set_header("Access-Control-Allow-Headers", "*")
    response.set_header("Access-Control-Allow-Methods", "GET, HEAD")
    response.set_header("Access-Control-Max-Age", "86400")
    head :no_content
  end

  def show
    upload = Upload.includes(:blob).find(params[:id])
    expires_in 1.year, public: true
    redirect_to upload.assets_url, allow_other_host: true
  rescue ActiveRecord::RecordNotFound
    respond_with_error(
      code: :not_found,
      status: :not_found,
      message: "No upload exists with ID #{params[:id]}.",
      hint: "The file may have been deleted. Files are addressed as /<id>/<filename>; the ID comes from the upload response."
    )
  end

  def rescue
    url = params[:url]

    if url.blank?
      respond_with_error(
        code: :missing_parameter,
        status: :bad_request,
        message: "Required parameter `url` is missing.",
        hint: "Call /rescue?url=<the original URL the file was imported from>.",
        parameter: "url"
      )
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

  def set_cors_headers = response.set_header("Access-Control-Allow-Origin", "*")

  def render_not_found_response(url)
    if request.format == :json
      render_json_error(
        code: :original_url_not_found,
        status: :not_found,
        message: "No file on the CDN was imported from #{url}.",
        hint: "Upload it at https://#{JSONErrorResponses.canonical_host} to give it a CDN URL.",
        original_url: url
      )
    elsif url.match?(/\.(png|jpe?g)$/i)
      render_error_image
    else
      head :not_found
    end
  end

  def respond_with_error(code:, status:, message:, hint:, **extra)
    if request.format == :json
      render_json_error(code: code, status: status, message: message, hint: hint, **extra)
    else
      head status
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
