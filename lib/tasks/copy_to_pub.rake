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
    i=0
    migrations = []
    Upload.select(:id, :blob_id).includes(:blob).find_each(batch_size: 5000) do |upload|
      blob = upload.blob
      old_key = blob.key
      new_key = "#{upload.id}/#{blob.filename.sanitized}"
      next if old_key == new_key

      migrations << { upload_id: upload.id, blob: blob, old_key: old_key, new_key: new_key }
      puts i+=1
    end

    puts "Found #{migrations.size} files to migrate (#{Upload.count - migrations.size} already migrated)"
    exit 0 if migrations.empty?

    require "concurrent"

    copied = Concurrent::AtomicFixnum.new(0)
    errors = Concurrent::Array.new
    progress = Concurrent::AtomicFixnum.new(0)

    pool = Concurrent::FixedThreadPool.new(67)

    migrations.each do |m|
      pool.post do
        begin
          blob = m[:blob]

          client.copy_object(
            bucket: bucket.name,
            copy_source: "#{bucket.name}/hackclub-cdn/#{m[:old_key]}",
            key: m[:new_key],
            content_type: blob.content_type || "application/octet-stream",
            content_disposition: "inline",
            metadata_directive: "REPLACE"
          )
          copied.increment
        rescue StandardError => e
          errors << { upload_id: m[:upload_id], old_key: m[:old_key], error: e.message }
        end
        print "\r[#{progress.increment}/#{migrations.size}] Copying..."
      end
    end

    pool.shutdown
    pool.wait_for_termination

    puts "\nCopied: #{copied.value}, Errors: #{errors.size}"
    errors.each { |err| puts "  - #{err[:upload_id]}: #{err[:error]}" } if errors.any?

    puts "\nRun `bin/rails storage:update_blob_keys` to update database keys"
  end

  desc "Phase 2: Update blob keys in database to point to new locations"
  task update_blob_keys: :environment do
    updated = 0
    Upload.select(:id, :blob_id).includes(:blob).find_each(batch_size: 5000) do |upload|
      blob = upload.blob
      new_key = "#{upload.id}/#{blob.filename.sanitized}"
      next if blob.key == new_key

      blob.update_column(:key, new_key)
      updated += 1
      print "\r[#{updated}] Updating keys..."
    end

    puts "\nUpdated #{updated} blob keys"
  end
end
