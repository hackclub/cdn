class ApplicationController < ActionController::Base
  before_action :require_authentication!

  helper_method :current_user, :signed_in?, :impersonating?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in? = current_user.present?

  def require_authentication!
    redirect_to login_path, alert: "Please sign in to continue." unless signed_in?
  end

  def impersonating? = false

  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back fallback_location: root_path
  end
end
