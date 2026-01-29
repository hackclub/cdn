module API
  module V4
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      attr_reader :current_user, :current_token

      before_action :authenticate!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

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

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: {
          error: "Validation failed",
          details: exception.record.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  end
end