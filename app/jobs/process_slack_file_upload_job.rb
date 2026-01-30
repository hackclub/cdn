# frozen_string_literal: true

class ProcessSlackFileUploadJob < ApplicationJob
  include ActionView::Helpers::NumberHelper

  queue_as :default

  class QuotaExceededError < StandardError
    attr_reader :reason, :details

    def initialize(reason, details = nil)
      @reason = reason
      @details = details
      super(details || reason.to_s)
    end
  end

  def perform(event)
    @channel_id = event["channel"]
    @message_ts = event["ts"]
    @slack_user_id = event["user"]
    @files = event["files"]

    return unless @files.present?

    @slack = SlackService.client
    @user = nil

    begin
      @user = find_or_create_user

      add_reaction("beachball")
      reply_in_thread(pick_flavor_message)

      uploads = process_files
      notify_success(uploads)
    rescue QuotaExceededError => e
      notify_quota_exceeded(e)
    rescue => e
      notify_error(e)
    end
  end

  private

  def find_or_create_user
    user = User.find_by(slack_id: @slack_user_id)

    unless user
      profile = @slack.users_info(user: @slack_user_id).user

      user = User.create!(
        slack_id: @slack_user_id,
        email: profile[:profile][:email] || "slack-#{@slack_user_id}@temp.hackclub.com",
        name: profile[:real_name] || profile[:name] || "Slack User"
      )
    end

    user
  end

  def process_files
    uploads = []

    @files.each do |file|
      original_url = file["url_private"]
      upload = Upload.create_from_url(
        original_url,
        user: @user,
        provenance: :slack,
        original_url: original_url,
        authorization: "Bearer #{Rails.application.config.slack.bot_token}"
      )

      enforce_quota!(upload)
      uploads << upload
    end

    uploads
  end

  def enforce_quota!(upload)
    quota_service = QuotaService.new(@user)
    policy = quota_service.current_policy

    if upload.byte_size > policy.max_file_size
      upload.destroy!
      raise QuotaExceededError.new(
        :file_too_large,
        "File is #{number_to_human_size(upload.byte_size)} but max is #{number_to_human_size(policy.max_file_size)}"
      )
    end

    return unless @user.total_storage_bytes > policy.max_total_storage

    upload.destroy!
    raise QuotaExceededError.new(
      :storage_exceeded,
      "You've used #{number_to_human_size(@user.total_storage_bytes)} of your #{number_to_human_size(policy.max_total_storage)} storage"
    )
  end

  def notify_success(uploads)
    remove_reaction("beachball")
    add_reaction("white_check_mark")

    @slack.chat_postMessage(
      channel: @channel_id,
      thread_ts: @message_ts,
      text: "Yeah! Here's yo' links",
      **render_slack_template("upload_success", uploads: uploads, slack_user_id: @slack_user_id)
    )
  end

  def notify_quota_exceeded(error)
    remove_reaction("beachball")
    add_reaction("x")

    error_text = case error.reason
    when :file_too_large
      ":warning: *File too large!* #{error.details}\n\nVerify your account at cdn.hackclub.com to upload larger files."
    when :storage_exceeded
      ":warning: *Storage quota exceeded!* #{error.details}\n\nVerify your account at cdn.hackclub.com for more storage, or delete some files."
    else
      "Quota exceeded - verify your account at cdn.hackclub.com"
    end

    reply_in_thread(error_text)
  end

  def notify_error(error)
    Rails.logger.error "Slack file upload failed: #{error.message}\n#{error.backtrace.join("\n")}"
    sentry_event = Sentry.capture_exception(error)
    sentry_id = sentry_event&.event_id || "unknown"

    return unless @slack

    begin
      remove_reaction("beachball")
      add_reaction("x")

      @slack.chat_postMessage(
        channel: @channel_id,
        thread_ts: @message_ts,
        text: "Something went wrong uploading your file",
        **render_slack_template("upload_error",
          flavor_message: pick_error_message,
          error_message: error.message,
          backtrace: format_backtrace(error.backtrace),
          sentry_id: sentry_id)
      )
    rescue => slack_error
      Rails.logger.error "Failed to send Slack error notification: #{slack_error.message}"
    end
  end

  def add_reaction(emoji)
    @slack.reactions_add(channel: @channel_id, timestamp: @message_ts, name: emoji)
  rescue StandardError
    nil
  end

  def remove_reaction(emoji)
    @slack.reactions_remove(channel: @channel_id, timestamp: @message_ts, name: emoji)
  rescue StandardError
    nil
  end

  def reply_in_thread(text)
    @slack.chat_postMessage(channel: @channel_id, thread_ts: @message_ts, text: text)
  end

  def render_slack_template(template, locals = {})
    json = ApplicationController.render(
      template: "slack/#{template}",
      formats: [:slack_message],
      locals:
    )
    JSON.parse(json, symbolize_names: true)
  end

  def pick_flavor_message
    # Collect all possible flavor messages based on file extensions
    flavor_messages = ["thanks, i'm gonna sell these to adfly!"]  # generic fallback

    @files.each do |file|
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

  def format_backtrace(backtrace)
    return "" if backtrace.blank?

    Rails.backtrace_cleaner.clean(backtrace).first(3).map do |line|
      if line =~ /^(.+):(\d+):in\s+'(.+)'$/
        file, line_num, method_name = $1, $2, $3
        url = "https://github.com/hackclub/cdn/blob/main/#{file}#L#{line_num}"
        "<#{url}|#{file}:#{line_num}> in `#{method_name}`"
      elsif line =~ /^(.+):(\d+)/
        file, line_num = $1, $2
        url = "https://github.com/hackclub/cdn/blob/main/#{file}#L#{line_num}"
        "<#{url}|#{file}:#{line_num}>"
      else
        line
      end
    end.join("\n")
  end

  def pick_error_message
    [
      "_cdnpheus sneezes and drops the files on the ground before blowing her nose on a blank jpeg._",
      "_cdnpheus trips and your files slip out of her hands and into an inconveniently placed sewer grate._",
      "_cdnpheus accidentally slips the files into a folder in her briefcase labeled \"homework\". she starts sweating profusely._"
    ].sample
  end
end
