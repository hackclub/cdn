# frozen_string_literal: true

# Every error has the same shape:
#
#   {
#     "error": "invalid_auth",              # legacy human/short string, kept stable
#     "code": "invalid_auth",               # stable machine-readable code
#     "message": "...",                     # what went wrong
#     "hint": "...",                        # how to fix it
#     "status": 401,
#     "documentation_url": "https://cdn.hackclub.com/docs/api"
#   }
module JSONErrorResponses
  extend ActiveSupport::Concern

  DOCUMENTATION_PATH = "/docs/api"

  STATUS_ALIASES = { unprocessable_entity: :unprocessable_content }.freeze

  def self.canonical_host = ENV["CDN_HOST"].presence || "cdn.hackclub.com"

  def self.documentation_url = "https://#{canonical_host}#{DOCUMENTATION_PATH}"

  def self.payload(code:, status:, message:, hint: nil, error: nil, **extra)
    body = {
      error: error || code.to_s,
      code: code.to_s,
      message: message
    }
    body[:hint] = hint if hint.present?
    body.merge!(extra)
    body[:status] = Rack::Utils.status_code(STATUS_ALIASES.fetch(status, status))
    body[:documentation_url] = documentation_url
    body
  end

  private

  def render_json_error(code:, status:, message:, hint: nil, error: nil, **extra)
    render json: JSONErrorResponses.payload(
      code: code, status: status, message: message, hint: hint, error: error, **extra
    ), status: status
  end

  def documentation_url = JSONErrorResponses.documentation_url
end
