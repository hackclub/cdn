module API
  module V4
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include JSONErrorResponses

      attr_reader :current_user, :current_token

      before_action :authenticate!
      before_action :set_sentry_context

      rescue_from StandardError, with: :handle_error
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :malformed_body

      private

      def authenticate!
        @current_token = authenticate_with_http_token do |token, _options|
          APIKey.find_by_token(token)
        end

        unless @current_token&.active?
          return render_json_error(
            code: :invalid_auth,
            status: :unauthorized,
            message: "The API key is missing, malformed, invalid, or revoked.",
            hint: "Send the key as an `Authorization: Bearer sk_cdn_...` header. Create or rotate a key at https://#{JSONErrorResponses.canonical_host}/api_keys."
          )
        end

        @current_user = @current_token.user
      end

      def set_sentry_context
        Sentry.set_user(id: current_user&.public_id) if current_user
        Sentry.set_tags(api_key_id: current_token&.id) if current_token
      end

      def not_found
        render_json_error(
          error: "Not found",
          code: :not_found,
          status: :not_found,
          message: "No resource matched the requested path or identifier.",
          hint: "Check the ID. Uploads are scoped to the API key's owner, so another user's upload reads as missing."
        )
      end

      def malformed_body(exception)
        render_json_error(
          error: "Malformed request body",
          code: :malformed_request,
          status: :bad_request,
          message: "The request body could not be parsed as #{request.media_type.presence || 'the declared content type'}: #{exception.message}",
          hint: "Send valid JSON with `Content-Type: application/json`, or drop the header if the request has no body."
        )
      end

      def unprocessable_entity(exception)
        render_json_error(
          error: "Validation failed",
          code: :validation_failed,
          status: :unprocessable_entity,
          message: exception.record.errors.full_messages.to_sentence.presence || "The request was well-formed but the record could not be saved.",
          hint: "Fix the fields listed in `details` and retry.",
          details: exception.record.errors.full_messages
        )
      end

      def handle_error(exception)
        raise exception if Rails.env.local?

        event = Sentry.capture_exception(exception)
        render_json_error(
          error: exception.message,
          code: :internal_error,
          status: :internal_server_error,
          message: exception.message,
          hint: "This is a bug on our end. Retry later. If it persists, report `error_id` in #cdn-dev on Slack or at https://github.com/hackclub/cdn/issues.",
          error_id: event&.event_id
        )
      end
    end
  end
end
