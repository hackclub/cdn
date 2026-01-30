# frozen_string_literal: true

class SlackService
  def initialize(bot_token = nil)
    @client = Slack::Web::Client.new(token: bot_token || Rails.application.config.slack.bot_token)
  end

  def add_reaction(channel:, timestamp:, emoji:)
    @client.reactions_add(
      channel: channel,
      timestamp: timestamp,
      name: emoji
    )
  end

  def remove_reaction(channel:, timestamp:, emoji:)
    @client.reactions_remove(
      channel: channel,
      timestamp: timestamp,
      name: emoji
    )
  end

  def reply_in_thread(channel:, thread_ts:, text:, blocks: nil)
    @client.chat_postMessage(
      channel: channel,
      thread_ts: thread_ts,
      text: text,
      blocks: blocks
    )
  end

  def fetch_user_profile(user_id)
    response = @client.users_info(user: user_id)
    response.user
  end
end
