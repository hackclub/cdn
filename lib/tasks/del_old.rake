# frozen_string_literal: true

namespace :storage do
  desc "Phase 2: Delete old keys (run after deploy)"
  task delete_old_keys: :environment do
    require "aws-sdk-s3"

    key_file = Rails.root.join("tmp/old_storage_keys.txt")
    unless File.exist?(key_file)
      puts "No old keys file found at #{key_file}"
      puts "Run storage:copy_to_public_keys first."
      exit 1
    end

    old_keys = File.read(key_file).split("\n").reject(&:blank?)
    puts "Found #{old_keys.size} old keys to delete"

    if old_keys.empty?
      puts "Nothing to delete."
      exit 0
    end

    service = ActiveStorage::Blob.service
    unless service.is_a?(ActiveStorage::Service::S3Service)
      puts "This task only works with S3/R2 storage. Current service: #{service.class}"
      exit 1
    end

    client = service.client.client
    bucket = service.bucket

    deleted = 0
    errors = []

    old_keys.each_with_index do |key, idx|
      print "\r[#{idx + 1}/#{old_keys.size}] Deleting..."

      begin
        client.delete_object(bucket: bucket.name, key: key)
        deleted += 1
      rescue StandardError => e
        puts "\n  ERROR deleting #{key}: #{e.message}"
        errors << { key: key, error: e.message }
      end
    end

    puts "\nDeleted: #{deleted}, Errors: #{errors.size}"

    if errors.empty?
      File.delete(key_file)
      puts "Cleanup complete!"
    else
      errors.each { |err| puts "  - #{err[:key]}: #{err[:error]}" }
    end
  end
end
