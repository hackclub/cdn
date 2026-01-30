Rails.application.config.slack = ActiveSupport::OrderedOptions.new
Rails.application.config.slack.bot_token = ENV.fetch("SLACK_BOT_TOKEN", nil)
Rails.application.config.slack.signing_secret = ENV.fetch("SLACK_SIGNING_SECRET", nil)
Rails.application.config.slack.cdn_channels = ENV.fetch("CDN_CHANNELS", "").split(",").map(&:strip)

Slack::Events.configure do |config|
  config.signing_secret = Rails.application.config.slack.signing_secret
end
