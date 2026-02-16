# frozen_string_literal: true

module API
  module V4
    class APIKeysController < ApplicationController
      def revoke
        api_key = current_token
        owner_email = current_user.email
        key_name = api_key.name

        api_key.revoke!

        render json: {
          success: true,
          owner_email: owner_email,
          key_name: key_name,
          status: "complete"
        }, status: :ok
      end
    end
  end
end
