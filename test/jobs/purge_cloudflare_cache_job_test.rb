# frozen_string_literal: true

require "test_helper"

class PurgeCloudflareCacheJobTest < ActiveSupport::TestCase
  ENV_KEYS = %w[
    CLOUDFLARE_API_TOKEN CLOUDFLARE_ZONE_ID CLOUDFLARE_ASSETS_ZONE_ID
    CDN_HOST CDN_ASSETS_HOST
  ].freeze

  CDN_URL = "https://cdn.hackclub.com/an-id/file.png"
  ASSETS_URL = "https://user-cdn.hackclub-assets.com/an-id/file.png"

  CONFIGURED = {
    "CLOUDFLARE_API_TOKEN" => "token",
    "CLOUDFLARE_ZONE_ID" => "cdn-zone",
    "CLOUDFLARE_ASSETS_ZONE_ID" => "assets-zone"
  }.freeze

  # Clears every var this job reads so a developer's .env can't change results.
  def with_env(values)
    previous = ENV_KEYS.index_with { |key| ENV[key] }
    ENV_KEYS.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key.to_s] = value }
    yield
  ensure
    ENV_KEYS.each { |key| previous[key].nil? ? ENV.delete(key) : ENV[key] = previous[key] }
  end

  # The test environment is "local", where a missing token is allowed to no-op.
  def with_rails_env(name)
    previous = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = previous
  end

  # Returns [job, requests] where the job's Faraday connection is stubbed and
  # every purge call is appended to requests.
  def stubbed_job(status: 200, body: { "success" => true, "errors" => [] })
    requests = []

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{\A/client/v4/zones/[^/]+/purge_cache\z}) do |env|
        requests << {
          zone: env.url.path[%r{/zones/([^/]+)/}, 1],
          files: JSON.parse(env.body).fetch("files"),
          authorization: env.request_headers["Authorization"]
        }
        [ status, { "Content-Type" => "application/json" }, body.to_json ]
      end
    end

    connection = Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter :test, stubs
    end

    job = PurgeCloudflareCacheJob.new
    job.define_singleton_method(:connection) { connection }
    [ job, requests ]
  end

  test "purges each host in its own zone" do
    with_env(CONFIGURED) do
      job, requests = stubbed_job
      job.perform([ ASSETS_URL, CDN_URL ])

      assert_equal 2, requests.size
      assert_equal [ ASSETS_URL ], requests.find { |r| r[:zone] == "assets-zone" }[:files]
      assert_equal [ CDN_URL ], requests.find { |r| r[:zone] == "cdn-zone" }[:files]
      assert_equal [ "Bearer token" ], requests.map { |r| r[:authorization] }.uniq
    end
  end

  test "respects CDN_HOST and CDN_ASSETS_HOST overrides" do
    with_env(CONFIGURED.merge(
      "CDN_HOST" => "cdn.example.com",
      "CDN_ASSETS_HOST" => "assets.example.net"
    )) do
      job, requests = stubbed_job
      job.perform([ "https://assets.example.net/key", "https://cdn.example.com/an-id/f.png" ])

      assert_equal %w[assets-zone cdn-zone], requests.map { |r| r[:zone] }.sort
    end
  end

  test "does nothing when there are no urls" do
    with_env(CONFIGURED) do
      job, requests = stubbed_job
      job.perform([])
      job.perform(nil)

      assert_empty requests
    end
  end

  # Matches the each_slice size in the job; Cloudflare's per-request limit is 30
  # URLs outside Enterprise.
  BATCH_SIZE = 30

  test "deduplicates urls and batches them per request" do
    with_env(CONFIGURED) do
      job, requests = stubbed_job
      urls = Array.new(BATCH_SIZE + 5) do |i|
        "https://user-cdn.hackclub-assets.com/id-#{i}/f.png"
      end
      job.perform(urls + [ urls.first ])

      assert_equal 2, requests.size
      assert_equal BATCH_SIZE, requests.first[:files].size
      assert_equal 5, requests.second[:files].size
    end
  end

  test "raises when the assets zone is not configured" do
    with_env(CONFIGURED.except("CLOUDFLARE_ASSETS_ZONE_ID")) do
      job, = stubbed_job

      error = assert_raises(PurgeCloudflareCacheJob::ConfigurationError) do
        job.perform([ ASSETS_URL ])
      end
      assert_match "user-cdn.hackclub-assets.com", error.message
    end
  end

  test "raises when a url belongs to neither configured host" do
    with_env(CONFIGURED) do
      job, = stubbed_job

      assert_raises(PurgeCloudflareCacheJob::ConfigurationError) do
        job.perform([ "https://somewhere-else.example.com/key" ])
      end
    end
  end

  test "raises when both zone ids are the same" do
    with_env(CONFIGURED.merge("CLOUDFLARE_ASSETS_ZONE_ID" => "cdn-zone")) do
      job, requests = stubbed_job

      error = assert_raises(PurgeCloudflareCacheJob::ConfigurationError) do
        job.perform([ ASSETS_URL ])
      end
      assert_match "same zone", error.message
      assert_empty requests
    end
  end

  test "raises outside local environments when the api token is missing" do
    with_env(CONFIGURED.except("CLOUDFLARE_API_TOKEN")) do
      with_rails_env("production") do
        job, requests = stubbed_job

        assert_raises(PurgeCloudflareCacheJob::ConfigurationError) do
          job.perform([ ASSETS_URL ])
        end
        assert_empty requests
      end
    end
  end

  test "skips quietly in local environments when the api token is missing" do
    with_env(CONFIGURED.except("CLOUDFLARE_API_TOKEN")) do
      job, requests = stubbed_job

      assert_nil job.perform([ ASSETS_URL ])
      assert_empty requests
    end
  end

  # Cloudflare answers 200 with success:false for a rejected purge, which the
  # previous implementation treated as a win.
  test "raises when cloudflare reports failure in a 200 response" do
    with_env(CONFIGURED) do
      job, = stubbed_job(body: {
        "success" => false,
        "errors" => [ { "code" => 1012, "message" => "Unable to purge" } ]
      })

      error = assert_raises(PurgeCloudflareCacheJob::PurgeFailedError) do
        job.perform([ ASSETS_URL ])
      end
      assert_match "1012", error.message
    end
  end

  test "raises when cloudflare rejects the request" do
    with_env(CONFIGURED) do
      job, = stubbed_job(status: 403, body: { "success" => false })

      error = assert_raises(PurgeCloudflareCacheJob::PurgeFailedError) do
        job.perform([ ASSETS_URL ])
      end
      assert_match "403", error.message
    end
  end
end
