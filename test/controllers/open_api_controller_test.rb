# frozen_string_literal: true

require "test_helper"

class OpenAPIControllerTest < ActionDispatch::IntegrationTest
  test "serves the spec as JSON without authentication" do
    get "/openapi.json"

    assert_response :success
    assert_equal "application/json", response.media_type

    spec = JSON.parse(response.body)
    assert_equal "3.2.0", spec["openapi"]
    assert_equal "Hack Club CDN API", spec.dig("info", "title")
    assert spec.dig("info", "version").present?
    assert_equal "https://cdn.hackclub.com", spec.dig("servers", 0, "url")
    assert_equal "bearer", spec.dig("components", "securitySchemes", "bearerAuth", "scheme")
    assert_equal [ { "bearerAuth" => [] } ], spec["security"]
  end

  test "spec documents every v4 endpoint" do
    get "/openapi.json"
    spec = JSON.parse(response.body)

    expected = {
      "/api/v4/me" => "get",
      "/api/v4/upload" => "post",
      "/api/v4/uploads" => "post",
      "/api/v4/upload_from_url" => "post",
      "/api/v4/uploads/{id}/rename" => "patch",
      "/api/v4/upload/{id}" => "delete",
      "/api/v4/uploads/batch" => "delete",
      "/api/v4/revoke" => "post"
    }

    expected.each do |path, verb|
      operation = spec.dig("paths", path, verb)
      assert operation.present?, "expected #{verb.upcase} #{path} to be documented"
      assert operation["operationId"].present?, "#{verb.upcase} #{path} needs an operationId"
      assert operation["summary"].present?, "#{verb.upcase} #{path} needs a summary"
      assert operation["responses"].present?, "#{verb.upcase} #{path} needs responses"
    end
  end

  test "every documented path is routable to a real controller action" do
    get "/openapi.json"
    spec = JSON.parse(response.body)

    spec["paths"].each do |path, operations|
      concrete = path.gsub("{id}", SecureRandom.uuid).gsub("{filename}", "file.png")

      operations.each_key do |verb|
        recognized = Rails.application.routes.recognize_path(concrete, method: verb.upcase)
        refute_equal "errors", recognized[:controller],
          "documented #{verb.upcase} #{path} does not match a real route"
      end
    end
  end

  test "every $ref in the spec resolves" do
    get "/openapi.json"
    spec = JSON.parse(response.body)

    refs(spec).each do |ref|
      pointer = ref.delete_prefix("#/").split("/")
      assert spec.dig(*pointer).present?, "unresolved $ref: #{ref}"
    end
  end

  test "documents the error envelope agents branch on" do
    get "/openapi.json"
    spec = JSON.parse(response.body)

    error = spec.dig("components", "schemas", "Error")
    assert_equal %w[error code message status documentation_url], error["required"]
    assert_includes error.dig("properties", "code", "enum"), "invalid_auth"
    assert_includes error.dig("properties", "code", "enum"), "quota_exceeded"

    unauthorized = spec.dig("paths", "/api/v4/me", "get", "responses", "401")
    assert_equal "#/components/schemas/Error",
      unauthorized.dig("content", "application/json", "schema", "$ref")
  end

  test "documents both rescue missing-parameter response variants" do
    get "/openapi.json"
    spec = JSON.parse(response.body)

    bad_request = spec.dig("paths", "/rescue", "get", "responses", "400")
    assert_includes bad_request["description"], "accept JSON"
    assert_includes bad_request["description"], "empty response body"
    assert_equal "#/components/schemas/Error",
      bad_request.dig("content", "application/json", "schema", "$ref")
  end

  test "serves the spec as YAML" do
    get "/openapi.yaml"

    assert_response :success
    assert_equal "application/yaml", response.media_type

    spec = YAML.safe_load(response.body)
    assert_equal "3.2.0", spec["openapi"]
    assert spec.dig("paths", "/api/v4/upload", "post").present?
  end

  test "is also reachable under /api and without an extension" do
    [ "/openapi", "/api/openapi", "/api/openapi.json" ].each do |path|
      get path

      assert_response :success, "expected #{path} to serve the spec"
      assert_equal "application/json", response.media_type, "expected #{path} to serve JSON"
      assert_equal "3.2.0", JSON.parse(response.body)["openapi"]
    end
  end

  test "is cacheable and readable cross-origin" do
    get "/openapi.json"

    assert_includes response.headers["Cache-Control"], "public"
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  private

  def refs(node)
    case node
    when Hash
      node.flat_map { |key, value| key == "$ref" ? [ value ] : refs(value) }
    when Array
      node.flat_map { |value| refs(value) }
    else
      []
    end
  end
end
