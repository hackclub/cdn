class PrivacyTokenUse < ApplicationRecord
  self.primary_key = :jti

  def self.consume!(jti)
    # insert_all distinguishes a uniqueness conflict from an unavailable database.
    result = insert_all([ { jti: jti, used_at: Time.current } ], unique_by: :jti, returning: %w[jti])
    raise Privacy::Error.new("replayed", 409) if result.rows.empty?
  end
end
