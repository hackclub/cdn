class ApplicationController < ActionController::Base
  before_action :require_authentication!
  before_action :set_sentry_context

  helper_method :current_user, :signed_in?, :impersonating?

  rescue_from StandardError, with: :handle_error

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in? = current_user.present?

  def require_authentication!
    redirect_to root_path, alert: "Please sign in to continue." unless signed_in?
  end

  def impersonating? = false

  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_sentry_context
    Sentry.set_user(id: current_user&.id, email: current_user&.email) if signed_in?
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back fallback_location: root_path
  end

  def handle_error(exception)
    raise exception if Rails.env.local?

    event = Sentry.capture_exception(exception)
    event_id = event&.event_id

    respond_to do |format|
      format.html do
        if request.path == root_path
          render "errors/internal_server_error", status: :internal_server_error, locals: { error_id: event_id, error_message: exception.message }
        else
          flash[:alert] = "Something went wrong: #{exception.message} (Error ID: #{event_id})"
          redirect_back fallback_location: root_path
        end
      end
      format.json { render json: { error: exception.message, error_id: event_id }, status: :internal_server_error }
    end
  end
end
