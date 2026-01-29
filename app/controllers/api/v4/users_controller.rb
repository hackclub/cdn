# frozen_string_literal: true

module API
  module V4
    class UsersController < ApplicationController
      def show
        render json: {
          id: current_user.public_id,
          email: current_user.email,
          name: current_user.name
        }
      end
    end
  end
end
