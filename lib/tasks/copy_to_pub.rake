# frozen_string_literal: true

namespace :storage do
  desc "Phase 1: Copy existing blobs to new key structure (safe, no deletions)"
  task copy_to_public_keys: :environment do
    require "aws-sdk-s3"

    service = ActiveStorage::Blob.service
    unless service.is_a?(ActiveStorage::Service::S3Service)
      puts "This task only works with S3/R2 storage. Current service: #{service.class}"
      exit 1
    end

    client = service.client.client
    bucket = service.bucket

    migrations = []
    Upload.includes(:blob).find_each do |upload|
      blob = upload.blob
      old_key = blob.key
      new_key = "#{upload.id}/#{blob.filename.sanitized}"
      next if old_key == new_key

      migrations << { upload_id: upload.id, blob_id: blob.id, old_key: old_key, new_key: new_key }
    end

    puts "Found #{migrations.size} files to migrate (#{Upload.count - migrations.size} already migrated)"
    exit 0 if migrations.empty?

    copied = 0
    errors = []
    old_keys_to_delete = []

    migrations.each_with_index do |m, idx|
      print "\r[#{idx + 1}/#{migrations.size}] Copying..."

      begin
        blob = ActiveStorage::Blob.find(m[:blob_id])

        client.copy_object(
          bucket: bucket.name,
          copy_source: "#{bucket.name}/#{m[:old_key]}",
          key: m[:new_key],
          content_type: blob.content_type || "application/octet-stream",
          content_disposition: "inline",
          metadata_directive: "REPLACE"
        )
        blob.update_column(:key, m[:new_key])
        old_keys_to_delete << m[:old_key]
        copied += 1
      rescue StandardError => e
        puts "\n  ERROR copying #{m[:upload_id]}: #{e.message}"
        errors << { upload_id: m[:upload_id], old_key: m[:old_key], error: e.message }
      end
    end

    puts "\nCopied: #{copied}, Errors: #{errors.size}"
    errors.each { |err| puts "  - #{err[:upload_id]}: #{err[:error]}" } if errors.any?

    if old_keys_to_delete.any?
      File.write(Rails.root.join("tmp/old_storage_keys.txt"), old_keys_to_delete.join("\n"))
      puts "\nOld keys saved to tmp/old_storage_keys.txt"
      puts "After deploying, run: bin/rails storage:delete_old_keys"
    end
  end
end
