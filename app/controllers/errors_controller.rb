# frozen_string_literal: true

class ErrorsController < ActionController::API
  include JSONErrorResponses

  def not_found
    render_json_error(
      code: :route_not_found,
      status: :not_found,
      message: "No route matches #{request.request_method} #{request.path}.",
      hint: "Read the machine-readable API surface at https://#{JSONErrorResponses.canonical_host}/openapi.json, or the docs at #{JSONErrorResponses.documentation_url}.",
      openapi_url: "https://#{JSONErrorResponses.canonical_host}/openapi.json",
      path: request.path,
      method: request.request_method
    )
  end
end
