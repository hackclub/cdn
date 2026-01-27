# frozen_string_literal: true

class HCAService
  BASE_URL = Rails.application.config.hack_club_auth.base_url

  def initialize(access_token)
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, parser_options: { symbolize_names: true }
      f.response :raise_error
      f.headers["Authorization"] = "Bearer #{access_token}"
    end
  end

  def me = @conn.get("/api/v1/me").body

  def check_verification(idv_id: nil, email: nil, slack_id: nil)
    params = { idv_id:, email:, slack_id: }.compact
    raise ArgumentError, "Provide one of: idv_id, email, or slack_id" if params.empty?

    @conn.get("/api/external/check", params).body
  end
end
