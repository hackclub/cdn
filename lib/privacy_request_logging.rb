# Silence the whole Rack request, including query strings, SQL binds and SDK events.
# Emit only a verified hub request_id and a fixed outcome after it completes.
require "stringio"

class PrivacyRequestLogging
  def self.privacy_path?(path)
    path.to_s.gsub(%r{/+}, "/").match?(%r{\A/api/privacy/(delete|export)(\.[^/]+)?/?\z})
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless self.class.privacy_path?(env["PATH_INFO"])

    # Rails instrumentation otherwise parses params even when the controller
    # never asks for them. Discard unsigned input before any parser runs.
    env["QUERY_STRING"] = ""
    env["rack.input"] = StringIO.new("")
    env["CONTENT_LENGTH"] = "0"

    response = Rails.logger.silence(Logger::UNKNOWN) { @app.call(env) }
    Rails.logger.info({ request_id: env["privacy.request_id"], outcome: env.fetch("privacy.outcome", "failed") }.to_json)
    response
  end
end
