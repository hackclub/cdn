# frozen_string_literal: true

class OpenAPIController < ApplicationController
  skip_before_action :require_authentication!

  def show
    expires_in 1.hour, public: true
    set_discovery_headers

    respond_to do |format|
      format.json { render json: OpenAPISpec.to_json }
      format.yaml { render plain: OpenAPISpec.to_yaml, content_type: "application/yaml" }
    end
  end

  private

  def set_discovery_headers
    response.set_header("Access-Control-Allow-Origin", "*")
  end
end
