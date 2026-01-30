# frozen_string_literal: true

module API
  module V4
    class UsersController < ApplicationController
      def show
        quota_service = QuotaService.new(current_user)
        usage = quota_service.current_usage

        render json: {
          id: current_user.public_id,
          email: current_user.email,
          name: current_user.name,
          storage_used: usage[:storage_used],
          storage_limit: usage[:storage_limit],
          quota_tier: usage[:policy]
        }
      end
    end
  end
end
