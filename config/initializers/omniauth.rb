Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hack_club,
    Rails.application.config.hack_club_auth.client_id,
    Rails.application.config.hack_club_auth.client_secret,
    scope: "openid email name slack_id verification_status",
    staging: !Rails.env.production?
end
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)
