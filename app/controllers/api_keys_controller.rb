# frozen_string_literal: true

class APIKeysController < ApplicationController
  before_action :set_api_key, only: [ :destroy ]

  def index
    @api_keys = current_user.api_keys.active.recent
  end

  def create
    @api_key = current_user.api_keys.create!(api_key_params)

    flash[:api_key_token] = @api_key.token
    redirect_to api_keys_path, notice: "API key created. Copy it now - you won't see it again!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to api_keys_path, alert: "Failed to create API key: #{e.message}"
  end

  def destroy
    authorize @api_key, :destroy?
    @api_key.revoke!
    redirect_to api_keys_path, notice: "API key revoked successfully."
  rescue Pundit::NotAuthorizedError
    redirect_to api_keys_path, alert: "You are not authorized to revoke this API key."
  end

  private

  def set_api_key
    @api_key = APIKey.find(params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:name)
  end
end
