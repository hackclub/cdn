ENV["RAILS_ENV"] ||= "test"
ENV["LOCKBOX_MASTER_KEY"] ||= "0" * 64
ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||= "0" * 32
ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||= "0" * 32
ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "0" * 32
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

module SignInHelper
  def sign_in(user)
    OmniAuth.config.mock_auth[:hack_club] = OmniAuth::AuthHash.new(
      provider: "hack_club",
      uid: user.hca_id,
      info: { email: user.email, name: user.name },
      credentials: { token: nil },
      extra: { raw_info: {} }
    )
    post hack_club_auth_url
    follow_redirect!  # hits sessions#create, which sets session[:user_id]
  end
end

# needed to handle auth
OmniAuth.config.test_mode = true
OmniAuth.config.request_validation_phase = ->(_env) { }

ActionDispatch::IntegrationTest.include SignInHelper
