# frozen_string_literal: true

# Serves /llms.txt: the agent-facing instruction file describing when to use
# this service and how to call it.
class LlmsController < ApplicationController
  skip_before_action :require_authentication!

  def show
    expires_in 1.hour, public: true
    response.set_header("Access-Control-Allow-Origin", "*")

    render plain: LlmsTxt.to_s, content_type: "text/plain"
  end
end
