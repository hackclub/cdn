require "test_helper"

class ExternalUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @file_path = external_upload_path(id: SecureRandom.uuid, filename: "test.png")
  end

  test "preflight permits range requests" do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    options @file_path, headers: {
      "Origin" => "https://example.com",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "range, x-accept-encoding"
    }

    assert_response :no_content
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_equal "*", response.headers["Access-Control-Allow-Headers"]
    assert_equal "GET, HEAD", response.headers["Access-Control-Allow-Methods"]
    assert_equal "86400", response.headers["Access-Control-Max-Age"]
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end
end
