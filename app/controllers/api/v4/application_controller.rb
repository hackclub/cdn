module API
  module V4
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      attr_reader :current_user, :current_token

      before_action :authenticate!
      before_action :set_sentry_context

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from StandardError, with: :handle_error

      private

      def authenticate!
        @current_token = authenticate_with_http_token do |token, _options|
          APIKey.find_by_token(token)
        end

        unless @current_token&.active?
          return render json: { error: "invalid_auth" }, status: :unauthorized
        end

        @current_user = @current_token.user
      end

      def set_sentry_context
        Sentry.set_user(id: current_user&.id) if current_user
        Sentry.set_tags(api_key_id: current_token&.hashid) if current_token
      end

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: {
          error: "Validation failed",
          details: exception.record.errors.full_messages
        }, status: :unprocessable_entity
      end

      def handle_error(exception)
        raise exception if Rails.env.local?

        event_id = Sentry.capture_exception(exception)
        render json: { error: exception.message, error_id: event_id }, status: :internal_server_error
      end
    end
  end
end