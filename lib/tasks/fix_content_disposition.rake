# frozen_string_literal: true

namespace :storage do
  desc "Update all existing blobs to have Content-Disposition: inline"
  task fix_content_disposition: :environment do
    require "aws-sdk-s3"

    service = ActiveStorage::Blob.service
    unless service.is_a?(ActiveStorage::Service::S3Service)
      puts "This task only works with S3/R2 storage. Current service: #{service.class}"
      exit 1
    end

    client = service.client
    bucket = service.bucket

    total = ActiveStorage::Blob.count
    updated = 0
    errors = 0

    puts "Updating Content-Disposition for #{total} blobs..."

    ActiveStorage::Blob.find_each.with_index do |blob, index|
      print "\rProcessing #{index + 1}/#{total}..."

      begin
        client.copy_object(
          bucket: bucket.name,
          copy_source: "#{bucket.name}/#{blob.key}",
          key: blob.key,
          content_disposition: "inline",
          content_type: blob.content_type,
          metadata_directive: "REPLACE"
        )
        updated += 1
      rescue Aws::S3::Errors::ServiceError => e
        puts "\nError updating #{blob.key}: #{e.message}"
        errors += 1
      end
    end

    puts "\nDone! Updated: #{updated}, Errors: #{errors}"
  end
end
