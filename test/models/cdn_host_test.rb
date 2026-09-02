# frozen_string_literal: true

require "test_helper"

class CDNHostTest < ActiveSupport::TestCase
  def with_cdn_host(value)
    previous = ENV["CDN_HOST"]
    value.nil? ? ENV.delete("CDN_HOST") : ENV["CDN_HOST"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("CDN_HOST") : ENV["CDN_HOST"] = previous
  end

  test "defaults to the production hostname when CDN_HOST is unset" do
    with_cdn_host(nil) do
      assert_equal "cdn.hackclub.com", CDNHost.host
      assert_equal "https://cdn.hackclub.com", CDNHost.base_url
    end
  end

  test "accepts a bare hostname" do
    with_cdn_host("cdn.example.com") do
      assert_equal "cdn.example.com", CDNHost.host
      assert_equal "https://cdn.example.com", CDNHost.base_url
    end
  end

  test "strips a scheme and trailing slash from CDN_HOST" do
    with_cdn_host("https://cdn.example.com/") do
      assert_equal "cdn.example.com", CDNHost.host
      assert_equal "https://cdn.example.com", CDNHost.base_url
    end
  end

  test "never produces a doubled scheme" do
    with_cdn_host("https://cdn.hackclub.com") do
      assert_equal "https://cdn.hackclub.com", CDNHost.base_url
      refute_includes CDNHost.base_url, "https://https://"
    end
  end
end
