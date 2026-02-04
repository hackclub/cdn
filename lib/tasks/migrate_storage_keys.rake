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

    # Build list of migrations needed
    migrations = []
    Upload.includes(:blob).find_each do |upload|
      blob = upload.blob
      old_key = blob.key
      new_key = "#{upload.id}/#{blob.filename.sanitized}"
      next if old_key == new_key

      migrations << { upload: upload, blob: blob, old_key: old_key, new_key: new_key }
    end

    puts "Found #{migrations.size} files to migrate (#{Upload.count - migrations.size} already migrated)"
    exit 0 if migrations.empty?

    # Phase 1: Copy all files
    puts "\n=== Phase 1: Copy files to new paths ==="
    copy_errors = []

    migrations.each_with_index do |m, idx|
      print "\r[#{idx + 1}/#{migrations.size}] Copying..."

      begin
        client.copy_object(
          bucket: bucket.name,
          copy_source: "#{bucket.name}/#{m[:old_key]}",
          key: m[:new_key],
          content_type: m[:blob].content_type,
          content_disposition: "inline",
          metadata_directive: "REPLACE"
        )
        m[:blob].update_column(:key, m[:new_key])
        m[:copied] = true
      rescue StandardError => e
        puts "\n  ERROR copying #{m[:upload].id}: #{e.message}"
        copy_errors << m.merge(error: e.message)
      end
    end

    copied = migrations.count { |m| m[:copied] }
    puts "\nPhase 1 complete. Copied: #{copied}, Errors: #{copy_errors.size}"

    if copy_errors.any?
      puts "Errors occurred during copy. Skipping delete phase."
      copy_errors.each { |err| puts "  - #{err[:upload].id}: #{err[:error]}" }
      exit 1
    end

    # Phase 2: Delete old files
    puts "\n=== Phase 2: Delete old files ==="
    delete_errors = []

    migrations.each_with_index do |m, idx|
      next unless m[:copied]

      print "\r[#{idx + 1}/#{migrations.size}] Deleting..."

      begin
        client.delete_object(bucket: bucket.name, key: m[:old_key])
      rescue StandardError => e
        puts "\n  ERROR deleting #{m[:old_key]}: #{e.message}"
        delete_errors << m.merge(error: e.message)
      end
    end

    puts "\nPhase 2 complete. Deleted: #{copied - delete_errors.size}, Errors: #{delete_errors.size}"
    puts "\nDone! Successfully migrated #{copied} files."
  end
end
