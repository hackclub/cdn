# frozen_string_literal: true

class SlackService
  def self.client
    @client ||= Slack::Web::Client.new(token: Rails.application.config.slack.bot_token)
  end
end
