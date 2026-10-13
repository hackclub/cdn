require "aws-sdk-s3"
require "active_storage/service/s3_service"

module Privacy
  class Files
    def initialize(blobs, uploads)
      @blobs, @uploads = blobs, uploads
    end

    def check_legacy!
      manifest = Rails.root.join("tmp/old_storage_keys.txt")
      raise Error.new("manual_review_required", 409) if manifest.exist? && manifest.read.strip.present?
      @blobs.map(&:service).uniq.each do |service|
        next unless service.is_a?(ActiveStorage::Service::S3Service)
        # Migration removed the old keys from the DB. Unknown copies cannot safely
        # be attributed to a subject: staff must finish the old-key cleanup first.
        old = client(service).list_objects_v2(bucket: service.bucket.name, prefix: "hackclub-cdn/", max_keys: 1)
        raise Error.new("manual_review_required", 409) if old.contents.any?
      end
    end

    def delete!
      @blobs.each do |blob|
        service = blob.service
        if service.is_a?(ActiveStorage::Service::S3Service)
          s3 = client(service)
          s3.delete_object(bucket: service.bucket.name, key: blob.key)
          prefix = "variants/#{blob.key}/"
          s3.list_objects_v2(bucket: service.bucket.name, prefix: prefix).each_page do |page|
            page.contents.each { |object| s3.delete_object(bucket: service.bucket.name, key: object.key) }
          end
        else
          service.delete(blob.key)
          service.delete_prefixed("variants/#{blob.key}/")
        end
      end
      purge_cache!
    rescue Error
      raise
    rescue StandardError
      raise Error.new("storage_unavailable", 503)
    end

    private

    def client(service)
      @clients ||= {}
      @clients[service] ||= begin
        config = service.client.client.config
        options = %i[region credentials endpoint force_path_style ssl_ca_bundle
          request_checksum_calculation response_checksum_validation stub_responses]
          .index_with { |key| config.public_send(key) }.compact
        Aws::S3::Client.new(**options, retry_limit: 0, http_open_timeout: 2,
          http_read_timeout: 3, http_wire_trace: false, logger: nil)
      end
    end

    def purge_cache!
      return if @uploads.empty?
      zone, token = ENV.values_at("CLOUDFLARE_ZONE_ID", "CLOUDFLARE_API_TOKEN")
      # Local/test storage is not served by Cloudflare. Production must configure
      # purging; silently skipping it would leave public file contents accessible.
      if zone.blank? || token.blank?
        raise Error.new("cache_unavailable", 503) if Rails.env.production?
        return
      end
      cdn_zone = ENV["CLOUDFLARE_CDN_ZONE_ID"].presence || zone
      urls_by_zone = Hash.new { |hash, key| hash[key] = [] }
      urls_by_zone[zone].concat(@uploads.map(&:assets_url))
      urls_by_zone[cdn_zone].concat(@uploads.map(&:cdn_url))
      conn = Faraday.new(url: "https://api.cloudflare.com") do |f|
        f.request :json
        f.response :json
        f.options.open_timeout = 2
        f.options.timeout = 3
      end
      urls_by_zone.each do |zone_id, urls|
        urls.uniq.each_slice(100) do |batch|
          response = conn.post("/client/v4/zones/#{zone_id}/purge_cache", { files: batch }, { "Authorization" => "Bearer #{token}" })
          unless response.success? && response.body.is_a?(Hash) && response.body["success"] == true
            raise Error.new("cache_unavailable", 503)
          end
        end
      end
    end
  end
end
