# frozen_string_literal: true

class ProcessSlackFileUploadJob < ApplicationJob
  queue_as :default

  class QuotaExceededError < StandardError; end

  def perform(event)
    channel_id = event["channel"]
    message_ts = event["ts"]
    slack_user_id = event["user"]
    files = event["files"]

    return unless files.present?

    slack_service = nil

    begin
      slack_service = SlackService.new
      bot_token = Rails.application.config.slack.bot_token
      # Find or create user
      user = find_or_create_user(slack_user_id, slack_service)

      # Add beachball reaction
      slack_service.add_reaction(
        channel: channel_id,
        timestamp: message_ts,
        emoji: "beach_ball"
      )

      # Send initial funny flavor message
      flavor_message = pick_flavor_message(files)
      slack_service.reply_in_thread(
        channel: channel_id,
        thread_ts: message_ts,
        text: flavor_message
      )

      uploads = []

      # Process each file
      files.each do |file|
        original_url = file["url_private"]

        # Create upload with Slack authorization
        upload = Upload.create_from_url(
          original_url,
          user: user,
          provenance: :slack,
          original_url: original_url,
          authorization: "Bearer #{bot_token}"
        )

        # Check quota AFTER upload (size unknown beforehand)
        quota_service = QuotaService.new(user)
        if user.total_storage_bytes > quota_service.current_policy.max_total_storage
          upload.destroy!
          raise QuotaExceededError, "Storage quota exceeded"
        end

        uploads << upload
      end

      # Success: remove beachball, add checkmark, reply with Block Kit message
      slack_service.remove_reaction(
        channel: channel_id,
        timestamp: message_ts,
        emoji: "beach_ball"
      )

      slack_service.add_reaction(
        channel: channel_id,
        timestamp: message_ts,
        emoji: "white_check_mark"
      )

      # Build Block Kit message using Slocks template
      blocks_json = ApplicationController.render(
        template: "slack/upload_success",
        formats: [:slack_message],
        locals: {
          uploads: uploads,
          slack_user_id: slack_user_id
        }
      )

      slack_service.reply_in_thread(
        channel: channel_id,
        thread_ts: message_ts,
        text: "Yeah! Here's yo' links", # Fallback for notifications
        blocks: JSON.parse(blocks_json)
      )

    rescue QuotaExceededError => e
      # Quota exceeded: remove beachball, add X, reply with error
      slack_service.remove_reaction(
        channel: channel_id,
        timestamp: message_ts,
        emoji: "beach_ball"
      )

      slack_service.add_reaction(
        channel: channel_id,
        timestamp: message_ts,
        emoji: "x"
      )

      slack_service.reply_in_thread(
        channel: channel_id,
        thread_ts: message_ts,
        text: "Storage quota exceeded - verify your account at cdn.hackclub.com"
      )

    rescue => e
      # General error: remove beachball, add X, reply with error and Sentry ID
      Rails.logger.error "Slack file upload failed: #{e.message}\n#{e.backtrace.join("\n")}"
      sentry_event = Sentry.capture_exception(e)
      sentry_id = sentry_event&.event_id || "unknown"

      begin
        if slack_service
          slack_service.remove_reaction(
            channel: channel_id,
            timestamp: message_ts,
            emoji: "beach_ball"
          )

          slack_service.add_reaction(
            channel: channel_id,
            timestamp: message_ts,
            emoji: "x"
          )

          error_message = pick_error_message
          slack_service.reply_in_thread(
            channel: channel_id,
            thread_ts: message_ts,
            text: "#{error_message}\n\n_Error ID: `#{sentry_id}`_"
          )
        end
      rescue => slack_error
        Rails.logger.error "Failed to send Slack error notification: #{slack_error.message}"
      end
    end
  end

  private

  def find_or_create_user(slack_user_id, slack_service)
    # First check if user exists
    user = User.find_by(slack_id: slack_user_id)

    unless user
      # Fetch profile from Slack API
      profile = slack_service.fetch_user_profile(slack_user_id)

      puts profile
      user = User.create!(
        slack_id: slack_user_id,
        email: profile[:profile][:email] || "slack-#{slack_user_id}@temp.hackclub.com",
        name: profile[:real_name] || profile[:name] || "Slack User"
      )
    end

    user
  end

  def pick_flavor_message(files)
    # Collect all possible flavor messages based on file extensions
    flavor_messages = ["thanks, i'm gonna sell these to adfly!"]  # generic fallback

    files.each do |file|
      ext = File.extname(file["name"]).delete_prefix(".").downcase
      case ext
      when "gif"
        flavor_messages += ["_gif_ that file to me and i'll upload it", "_gif_ me all all your files!"]
      when "heic"
        flavor_messages << "What the heic???"
      when "mov"
        flavor_messages << "I'll _mov_ that to a permanent link for you"
      when "html"
        flavor_messages += ["Oh, launching a new website?", "uwu, what's this site?", "WooOOAAah hey! Are you serving a site?", "h-t-m-ello :wave:"]
      when "rar"
        flavor_messages += [".rawr xD", "i also go \"rar\" sometimes!"]
      end
    end

    flavor_messages.sample
  end

  def pick_error_message
    [
      "_cdnpheus sneezes and drops the files on the ground before blowing her nose on a blank jpeg._",
      "_cdnpheus trips and your files slip out of her hands and into an inconveniently placed sewer grate._",
      "_cdnpheus accidentally slips the files into a folder in her briefcase labeled \"homework\". she starts sweating profusely._"
    ].sample
  end
end
