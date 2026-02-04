# frozen_string_literal: true

namespace :storage do
  desc "Migrate existing blobs to public key structure: <upload-id>/<filename>"
  task migrate_to_public_keys: :environment do
    require "aws-sdk-s3"

    service = ActiveStorage::Blob.service
    unless service.is_a?(ActiveStorage::Service::S3Service)
      puts "This task only works with S3/R2 storage. Current service: #{service.class}"
      exit 1
    end

    client = service.client.client
    bucket = service.bucket

    total = Upload.count
    migrated = 0
    skipped = 0
    errors = 0

    puts "Migrating #{total} uploads to public key structure..."

    Upload.includes(:blob).find_each.with_index do |upload, idx|
      blob = upload.blob
      old_key = blob.key
      new_key = "#{upload.id}/#{blob.filename.sanitized}"

      print "\r[#{idx + 1}/#{total}] Processing..."

      if old_key == new_key
        skipped += 1
        next
      end

      begin
        client.copy_object(
          bucket: bucket.name,
          copy_source: "#{bucket.name}/#{old_key}",
          key: new_key,
          content_type: blob.content_type,
          content_disposition: "inline",
          metadata_directive: "REPLACE"
        )

        blob.update_column(:key, new_key)
        client.delete_object(bucket: bucket.name, key: old_key)
        migrated += 1
      rescue Aws::S3::Errors::ServiceError => e
        puts "\n  ERROR migrating #{upload.id}: #{e.message}"
        errors += 1
      end
    end

    puts "\nDone! Migrated: #{migrated}, Skipped: #{skipped}, Errors: #{errors}"
  end
end
