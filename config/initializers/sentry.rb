Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.sample_rate = 0.25
  config.traces_sample_rate = 0.1
  config.send_default_pii = false
  config.enabled_environments = %w[production staging]
  # Privacy requests must never reach telemetry with headers, claims or SQL binds.
  privacy_request = ->(event) { PrivacyRequestLogging.privacy_path?(event.request&.url.to_s.split("?").first.to_s.sub(%r{\Ahttps?://[^/]+}, "")) }
  config.before_send = ->(event, _hint) { privacy_request.call(event) ? nil : event }
  config.before_send_transaction = ->(event, _hint) { privacy_request.call(event) ? nil : event }
end
