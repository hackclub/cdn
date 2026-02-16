# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_authentication!, only: %i[create failure]

  def create
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_omniauth(auth)
    session[:user_id] = user.id

    # Check and upgrade verification status if needed
    QuotaService.new(user).check_and_upgrade_verification!

    redirect_to root_path, notice: "Signed in successfully!"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out successfully!"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
end
