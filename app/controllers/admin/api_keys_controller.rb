# frozen_string_literal: true

module Admin
  class APIKeysController < ApplicationController
    def destroy
      api_key = APIKey.find(params[:id])
      user = api_key.user
      api_key.revoke!
      redirect_to admin_user_path(user), notice: "API key '#{api_key.name}' revoked."
    end
  end
end
