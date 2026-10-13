require "test_helper"
require "active_storage/service/s3_service"

class API::PrivacyControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  parallelize(workers: 1)

  unless SolidQueue::Job.table_exists?
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/queue_schema.rb")
  end

  setup do
    Privacy::Token.instance_variables.each { |name| Privacy::Token.remove_instance_variable(name) }
    @key = OpenSSL::PKey::EC.generate("prime256v1")
    @jwk = JWT::JWK.new(@key, kid: "test-key").export
    @jwks = Struct.new(:body) { def success? = true }.new({ keys: [ @jwk ] }.to_json)
    @user = users(:one)
    @user.update!(slack_id: "U_PRIVACY_TEST")
    @claims = {
      "iss" => "hackclub-privacy", "aud" => "cdn", "iat" => Time.now.to_i,
      "exp" => Time.now.to_i + 300, "jti" => SecureRandom.uuid,
      "request_id" => SecureRandom.uuid, "action" => "delete", "dry_run" => true,
      "subject" => { "emails" => [ @user.email.upcase ], "slack_id" => nil, "identity_id" => nil }
    }
    @blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private content"), filename: "private.txt", content_type: "text/plain")
    @upload = Upload.create!(user: @user, blob: @blob, provenance: :web)
    @api_key = APIKey.create!(user: @user, name: "personal")
  end

  teardown do
    @blob.service.delete(@blob.key)
  end

  def token(claims = @claims, header = {})
    JWT.encode(claims, @key, "ES256", { "typ" => "JWT", "kid" => "test-key" }.merge(header))
  end

  def privacy_post(action = "delete", signed_token: token, query: "", body: nil)
    with_stub(Faraday, :get, @jwks) do
      post "/api/privacy/#{action}#{query}", params: body,
        headers: { "Authorization" => "Bearer #{signed_token}", "Accept" => "application/json" }
    end
  end

  test "dry run executes deletes and rolls back without storage or queue effects" do
    job = slack_job
    failure = SolidQueue::FailedExecution.create!(job_id: job.id, error: "private failure")
    assert_no_enqueued_jobs do
      with_stub(@blob.service, :delete, ->(*) { flunk "dry run touched files" }) do
        privacy_post
      end
    end
    assert_response :ok
    result = response.parsed_body
    assert_equal @claims["request_id"], result["request_id"]
    assert_equal true, result["dry_run"]
    assert_equal true, result["found"]
    assert_equal 1, result["deleted"]["users"]
    assert_equal 1, result["deleted"]["uploads"]
    assert_equal 1, result["deleted"]["api_keys"]
    assert_equal 1, result["deleted"]["active_storage_blobs"]
    assert_equal 1, result["deleted"]["solid_queue_failed_executions"]
    assert User.exists?(@user.id)
    assert APIKey.exists?(@api_key.id)
    assert Upload.exists?(@upload.id)
    assert ActiveStorage::Blob.exists?(@blob.id)
    assert SolidQueue::Job.exists?(job.id)
    assert SolidQueue::FailedExecution.exists?(failure.id)
    assert @blob.service.exist?(@blob.key)
    assert PrivacyTokenUse.exists?(@claims["jti"])
  end

  test "real deletion gives the reviewed counts and deletes files before commit" do
    slack_job
    privacy_post
    reviewed = response.parsed_body["deleted"]
    @claims["jti"] = SecureRandom.uuid
    @claims["dry_run"] = false
    deleted_before_commit = false
    original_delete = @blob.service.method(:delete)
    with_stub(@blob.service, :delete, lambda { |key|
      assert User.connection.transaction_open?
      deleted_before_commit = true
      original_delete.call(key)
    }) { privacy_post }
    assert_response :ok
    assert deleted_before_commit
    assert_equal reviewed, response.parsed_body["deleted"]
    assert_not User.exists?(@user.id)
    assert_not Upload.exists?(@upload.id)
    assert_not APIKey.exists?(@api_key.id)
    assert_not ActiveStorage::Blob.exists?(@blob.id)
    assert_not @blob.service.exist?(@blob.key)
    @claims["jti"] = SecureRandom.uuid
    privacy_post
    assert_response :ok
    assert_equal false, response.parsed_body["found"]
  end

  test "storage failures roll back primary and queue deletions and allow a fresh-token retry" do
    job = slack_job
    @claims["dry_run"] = false
    with_stub(@blob.service, :delete, ->(*) { raise IOError, "email must not leak" }) { privacy_post }
    assert_response :service_unavailable
    assert_equal({ "error" => "storage_unavailable" }, response.parsed_body)
    assert User.exists?(@user.id)
    assert Upload.exists?(@upload.id)
    assert SolidQueue::Job.exists?(job.id)
    @claims["jti"] = SecureRandom.uuid
    privacy_post
    assert_response :ok
  end

  test "export reports counts without changing account jobs files or cached data" do
    job = slack_job
    @claims["action"] = "export"
    @claims["dry_run"] = false
    with_stub(@blob.service, :delete, ->(*) { flunk "export touched files" }) { privacy_post("export") }
    assert_response :ok
    assert_equal false, response.parsed_body["dry_run"]
    assert_equal 1, response.parsed_body["deleted"]["uploads"]
    assert User.exists?(@user.id)
    assert APIKey.exists?(@api_key.id)
    assert Upload.exists?(@upload.id)
    assert SolidQueue::Job.exists?(job.id)
    assert @blob.service.exist?(@blob.key)
  end

  test "replays return 409 including after dry runs and exports" do
    privacy_post
    privacy_post
    assert_response :conflict
    assert_equal({ "error" => "replayed" }, response.parsed_body)
    @claims.merge!("jti" => SecureRandom.uuid, "action" => "export")
    privacy_post("export")
    privacy_post("export")
    assert_response :conflict
  end

  test "token subject alone determines identity and matches every case insensitive email" do
    duplicate = User.create!(email: @user.email.upcase)
    privacy_post(query: "?email=#{users(:two).email}", body: { email: users(:two).email, slack_id: "ignored" })
    assert_response :ok
    assert_equal 2, response.parsed_body["deleted"]["users"]
    assert User.exists?(duplicate.id)
    assert User.exists?(users(:two).id)
  end

  test "slack and identity identifiers match independently" do
    [ { "slack_id" => @user.slack_id }, { "identity_id" => @user.hca_id } ].each do |identifier|
      @claims["subject"] = { "emails" => [], "slack_id" => nil, "identity_id" => nil }.merge(identifier)
      @claims["jti"] = SecureRandom.uuid
      privacy_post
      assert_response :ok
      assert_equal true, response.parsed_body["found"]
    end
  end

  test "no match responds with counts and exactly the signed dry_run" do
    @claims["subject"] = { "emails" => [ "missing@example.com" ] }
    privacy_post
    assert_response :ok
    assert_equal false, response.parsed_body["found"]
    assert_equal true, response.parsed_body["dry_run"]
    assert response.parsed_body["deleted"].values.all?(&:zero?)
    assert_equal [], response.parsed_body["retained"]
  end

  test "shared files survive detached and are reported" do
    other = Upload.create!(user: users(:two), blob: @blob, provenance: :web)
    @claims["dry_run"] = false
    privacy_post
    assert_response :ok
    assert_equal 0, response.parsed_body["deleted"]["active_storage_blobs"]
    assert_equal 1, response.parsed_body["retained"].first["count"]
    assert Upload.exists?(other.id)
    assert ActiveStorage::Blob.exists?(@blob.id)
    assert @blob.service.exist?(@blob.key)
  end

  test "attachments and tracked variants are deleted through the same transaction" do
    variant = ActiveStorage::VariantRecord.create!(blob: @blob, variation_digest: "privacy-test")
    attachment = ActiveStorage::Attachment.create!(record: variant, name: "image", blob: @blob)
    privacy_post
    assert_response :ok
    assert_equal 1, response.parsed_body["deleted"]["active_storage_variant_records"]
    assert_equal 1, response.parsed_body["deleted"]["active_storage_attachments"]
    assert ActiveStorage::VariantRecord.exists?(variant.id)
    assert ActiveStorage::Attachment.exists?(attachment.id)
  end

  test "running upload jobs require manual review before any deletion" do
    job = slack_job
    SolidQueue::ClaimedExecution.insert_all!([ { job_id: job.id, created_at: Time.current } ])
    privacy_post
    assert_response :conflict
    assert_equal({ "error" => "manual_review_required" }, response.parsed_body)
    assert User.exists?(@user.id)
    assert @blob.service.exist?(@blob.key)
  end

  test "pending Slack data is erased even before an account has been created" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "ProcessSlackFileUploadJob",
      arguments: { "arguments" => [ { "user" => "U_PENDING_PRIVACY", "files" => [] } ] })
    @claims["subject"] = { "emails" => [], "slack_id" => "U_PENDING_PRIVACY" }
    @claims["dry_run"] = false
    privacy_post
    assert_response :ok
    assert_equal true, response.parsed_body["found"]
    assert_equal 0, response.parsed_body["deleted"]["users"]
    assert_equal 1, response.parsed_body["deleted"]["solid_queue_jobs"]
    assert_not SolidQueue::Job.exists?(job.id)
    assert User.exists?(@user.id)
  end

  test "registered shared integration keys require manual review" do
    original = ENV["PRIVACY_SHARED_API_KEY_IDS"]
    ENV["PRIVACY_SHARED_API_KEY_IDS"] = @api_key.id.to_s
    privacy_post
    assert_response :conflict
    assert_equal({ "error" => "manual_review_required" }, response.parsed_body)
    assert APIKey.exists?(@api_key.id)
  ensure
    ENV["PRIVACY_SHARED_API_KEY_IDS"] = original
  end

  test "wrong endpoint action fails before replay bookkeeping" do
    privacy_post("export")
    assert_response :bad_request
    assert_equal({ "error" => "action_mismatch" }, response.parsed_body)
    assert_not PrivacyTokenUse.exists?(@claims["jti"])
  end

  test "invalid claims and headers are rejected" do
    [ { "aud" => "other" }, { "aud" => [ "cdn" ] }, { "iss" => "other" },
      { "iat" => Time.now.to_i + 31, "exp" => Time.now.to_i + 300 },
      { "exp" => Time.now.to_i - 31 }, { "exp" => Time.now.to_i + 301 },
      { "iat" => Time.now.to_f }, { "dry_run" => "true" }, { "subject" => {} },
      { "jti" => "" }, { "request_id" => "unsafe\nlog" } ].each do |changes|
      privacy_post(signed_token: token(@claims.merge(changes)))
      assert_response :unauthorized, changes.inspect
      assert_equal({ "error" => "invalid_token" }, response.parsed_body)
    end
    privacy_post(signed_token: token(@claims, "typ" => "other"))
    assert_response :unauthorized
    privacy_post(signed_token: JWT.encode(@claims, "secret", "HS256", { typ: "JWT", kid: "test-key" }))
    assert_response :unauthorized
    privacy_post(signed_token: "malformed")
    assert_response :unauthorized
    privacy_post(signed_token: JWT.encode(@claims, OpenSSL::PKey::EC.generate("prime256v1"), "ES256", { typ: "JWT", kid: "test-key" }))
    assert_response :unauthorized
  end

  test "clock leeway permits just expired and just future issued tokens" do
    @claims.merge!("iat" => Time.now.to_i - 320, "exp" => Time.now.to_i - 20)
    privacy_post
    assert_response :ok
    @claims.merge!("iat" => Time.now.to_i + 20, "exp" => Time.now.to_i + 300, "jti" => SecureRandom.uuid)
    privacy_post
    assert_response :ok
  end

  test "JWKS outages are retriable and do not consume a token" do
    with_stub(Faraday, :get, ->(*) { raise Faraday::ConnectionFailed }) do
      post "/api/privacy/delete", headers: { "Authorization" => "Bearer #{token}" }
    end
    assert_response :service_unavailable
    assert_equal({ "error" => "jwks_unavailable" }, response.parsed_body)
    assert_not PrivacyTokenUse.exists?(@claims["jti"])
  end

  test "JWKS caches keys and throttles unknown kid refreshes" do
    fetches = 0
    with_stub(Faraday, :get, ->(*) { fetches += 1; @jwks }) do
      Privacy::Token.verify!("Bearer #{token}", "delete")
      Privacy::Token.verify!("Bearer #{token}", "delete")
      assert_raises(Privacy::Error) { Privacy::Token.verify!("Bearer #{token(@claims, "kid" => "unknown")}", "delete") }
      assert_equal 1, fetches
      Privacy::Token.instance_variable_set(:@attempted_at, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 31)
      rotated = JWT::JWK.new(@key, kid: "rotated").export
      @jwks.body = { keys: [ rotated ] }.to_json
      Privacy::Token.verify!("Bearer #{token(@claims, "kid" => "rotated")}", "delete")
      assert_equal 2, fetches
    end
  end

  test "privacy request logging contains only request id and outcome even at debug level" do
    output = StringIO.new
    logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
    with_stub(Rails, :logger, logger) do
      middleware = PrivacyRequestLogging.new(lambda { |env|
        Rails.logger.error("secret-token private@example.com U_PRIVATE ident!private")
        env["privacy.request_id"] = @claims["request_id"]
        env["privacy.outcome"] = "delete_succeeded"
        [ 200, {}, [] ]
      })
      middleware.call("PATH_INFO" => "/api/privacy/delete", "QUERY_STRING" => "email=private@example.com")
    end
    assert_includes output.string, @claims["request_id"]
    assert_includes output.string, "delete_succeeded"
    %w[secret-token private@example.com U_PRIVATE ident!private].each { |secret| assert_not_includes output.string, secret }
  end

  test "the complete request suppresses query parameters JWT and SQL identifiers" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    Rails.logger.broadcast_to(logger)
    privacy_post(query: "?slack_id=U_SECRET&identity_id=ident%21secret&email=query%40example.com")
    assert_response :ok
    assert_includes output.string, @claims["request_id"]
    assert_includes output.string, "delete_succeeded"
    [ token, @user.email, @user.slack_id, @user.hca_id, "U_SECRET", "ident!secret", "query@example.com" ].each do |secret|
      assert_not_includes output.string, secret
    end
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end

  test "formatted routes ignore malformed unsigned input without parsing it" do
    with_stub(Faraday, :get, @jwks) do
      post "/api/privacy/delete.json?email=unsigned", params: "{invalid JSON",
        headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
    end
    assert_response :ok
    assert_equal true, response.parsed_body["found"]
  end

  test "Sentry excludes privacy events and transactions" do
    event = Sentry::Event.new(configuration: Sentry.configuration)
    request = Struct.new(:url).new("https://cdn.hackclub.com/api/privacy/delete?email=private")
    event.instance_variable_set(:@request, request)
    assert_nil Sentry.configuration.before_send.call(event, {})
    assert_nil Sentry.configuration.before_send_transaction.call(event, {})
    event.instance_variable_set(:@request, Struct.new(:url).new("https://cdn.hackclub.com/uploads"))
    assert_equal event, Sentry.configuration.before_send.call(event, {})
    event.instance_variable_set(:@request, nil)
    assert_equal event, Sentry.configuration.before_send.call(event, {})
  end

  test "an account erased after upload validation cannot write a new file" do
    account = User.create!(email: "stale-upload@example.invalid")
    service = BatchUploadService.new(user: account, provenance: :web)
    file = fixture_file_upload("test.png", "image/png")
    User.where(id: account.id).delete_all
    with_stub(ActiveStorage::Blob, :create_and_upload!, ->(*) { flunk "erased account wrote to storage" }) do
      assert_raises(ActiveRecord::RecordNotFound) { service.send(:create_upload, file) }
    end
  end

  test "Cloudflare failure rolls back the account after file removal and can be retried" do
    original_zone, original_token, original_cdn_zone = ENV.values_at("CLOUDFLARE_ZONE_ID", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_CDN_ZONE_ID")
    ENV["CLOUDFLARE_ZONE_ID"], ENV["CLOUDFLARE_API_TOKEN"] = "test-zone", "test-token"
    ENV.delete("CLOUDFLARE_CDN_ZONE_ID")
    response_type = Struct.new(:body) { def success? = true }
    cache_response = response_type.new({ "success" => false })
    posted_urls = []
    posted_batches = []
    connection = Object.new
    connection.define_singleton_method(:post) do |path, body, _headers|
      posted_urls.concat(body[:files])
      posted_batches << [ path, body[:files] ]
      cache_response
    end
    @claims["dry_run"] = false
    with_stub(Faraday, :new, connection) { privacy_post }
    assert_response :service_unavailable
    assert_equal({ "error" => "cache_unavailable" }, response.parsed_body)
    assert User.exists?(@user.id)
    assert Upload.exists?(@upload.id)
    assert_not @blob.service.exist?(@blob.key)
    assert_includes posted_urls, @upload.assets_url
    assert_includes posted_urls, @upload.cdn_url
    cache_response.body = { "success" => true }
    ENV["CLOUDFLARE_CDN_ZONE_ID"] = "redirect-zone"
    @claims["jti"] = SecureRandom.uuid
    with_stub(Faraday, :new, connection) { privacy_post }
    assert_response :ok
    assert_not User.exists?(@user.id)
    assert_equal [ @upload.assets_url ], posted_batches.find { |path, urls| path.include?("test-zone") && urls.size == 1 }.last
    assert_equal [ @upload.cdn_url ], posted_batches.find { |path, _urls| path.include?("redirect-zone") }.last
  ensure
    ENV["CLOUDFLARE_ZONE_ID"], ENV["CLOUDFLARE_API_TOKEN"], ENV["CLOUDFLARE_CDN_ZONE_ID"] = original_zone, original_token, original_cdn_zone
  end

  test "S3 cleanup removes current blobs and variants without inspecting or deleting legacy copies" do
    service = ActiveStorage::Service::S3Service.new(bucket: "privacy-test", region: "auto",
      access_key_id: "test", secret_access_key: "test", stub_responses: true)
    files = Privacy::Files.new([ @blob ], [])
    client = files.send(:client, service)
    client.stub_responses(:list_objects_v2, lambda { |context|
      assert_equal "variants/#{@blob.key}/", context.params[:prefix]
      { contents: [ { key: "variants/#{@blob.key}/old-variant" } ] }
    })
    with_stub(@blob, :service, service) { files.delete! }
    deletions = client.api_requests.select { |call| call[:operation_name] == :delete_object }.map { |call| call[:params][:key] }
    assert_equal [ @blob.key, "variants/#{@blob.key}/old-variant" ], deletions
  end

  test "legacy manifest does not block dry runs or deletion of current uploads" do
    Tempfile.create("legacy-storage-keys") do |manifest|
      manifest.write("hackclub-cdn/unknown-old-key\n")
      manifest.flush
      original_join = Rails.root.method(:join)
      with_stub(Rails.root, :join, lambda { |*paths|
        paths == [ "tmp/old_storage_keys.txt" ] ? Pathname.new(manifest.path) : original_join.call(*paths)
      }) do
        privacy_post
        assert_response :ok
        reviewed = response.parsed_body["deleted"]
        assert_equal 1, reviewed["uploads"]
        assert @blob.service.exist?(@blob.key)

        @claims["dry_run"] = false
        @claims["jti"] = SecureRandom.uuid
        privacy_post
        assert_response :ok
        assert_equal reviewed, response.parsed_body["deleted"]
        assert_not User.exists?(@user.id)
        assert_not Upload.exists?(@upload.id)
        assert_not ActiveStorage::Blob.exists?(@blob.id)
        assert_not @blob.service.exist?(@blob.key)
        assert_equal "hackclub-cdn/unknown-old-key\n", File.read(manifest.path)
      end
    end
  end

  private

  def with_stub(object, method, replacement)
    own_method = object.singleton_methods(false).include?(method)
    original = object.method(method)
    object.define_singleton_method(method) do |*args, **kwargs, &block|
      replacement.respond_to?(:call) ? replacement.call(*args, **kwargs, &block) : replacement
    end
    yield
  ensure
    if own_method
      object.define_singleton_method(method, original)
    else
      object.singleton_class.remove_method(method)
    end
  end

  def slack_job
    SolidQueue::Job.create!(queue_name: "default", class_name: "ProcessSlackFileUploadJob",
      arguments: { "arguments" => [ { "user" => @user.slack_id, "files" => [ { "url_private" => "https://slack.com/private" } ] } ] })
  end
end
