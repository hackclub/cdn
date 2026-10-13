module API
  class PrivacyController < ActionController::API
    def delete
      process_privacy("delete")
    end

    def export
      process_privacy("export")
    end

    private

    def process_privacy(action)
      claims = Privacy::Token.verify!(request.headers["Authorization"], action)
      request.env["privacy.request_id"] = claims["request_id"]
      PrivacyTokenUse.consume!(claims["jti"])
      result = Privacy::Eraser.new(claims).call(action)
      request.env["privacy.outcome"] = result["found"] ? "#{action}_succeeded" : "not_found"
      render json: result
    rescue Privacy::Error => e
      request.env["privacy.outcome"] = e.message
      render json: { error: e.message }, status: e.status
    rescue StandardError
      # Exception messages, SQL binds and SDK diagnostics may contain personal data.
      request.env["privacy.outcome"] = "dependency_unavailable"
      render json: { error: "dependency_unavailable" }, status: :service_unavailable
    end
  end
end
