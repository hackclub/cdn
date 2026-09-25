Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.sample_rate = 0.25
  config.traces_sample_rate = 0.1
  config.send_default_pii = false
  config.enabled_environments = %w[production staging]
end
