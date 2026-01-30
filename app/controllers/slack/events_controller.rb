# frozen_string_literal: true

module Slack
  class EventsController < ActionController::API
    before_action :verify_slack_signature

    def create
      # Handle Slack URL verification challenge
      if params[:type] == "url_verification"
        return render json: { challenge: params[:challenge] }
      end

      # Handle event callbacks
      if params[:type] == "event_callback"
        event = params[:event]

        # Filter to message events with files in monitored channels
        if event[:type] == "message" && event[:files].present? && monitored_channel?(event[:channel])
          ProcessSlackFileUploadJob.perform_later(event.to_unsafe_h)
        end
      end

      # Respond immediately (Slack requires < 3s response)
      head :ok
    end

    private

    def verify_slack_signature
      ::Slack::Events::Request.new(request).verify!
    rescue ::Slack::Events::Request::MissingSigningSecret,
           ::Slack::Events::Request::InvalidSignature,
           ::Slack::Events::Request::TimestampExpired
      render json: { error: "Invalid signature" }, status: :unauthorized
    end

    def monitored_channel?(channel_id)
      Rails.application.config.slack.cdn_channels.include?(channel_id)
    end
  end
end
