Hashid::Rails.configure do |config|
  config.salt = ENV.fetch("HASHID_SALT") { Rails.application.secret_key_base }
  config.min_hash_length = 6
end
