# frozen_string_literal: true

# /rescue looks files up with `Upload.find_by(original_url: url)`, but
# original_url had no index -- so every lookup was a sequential scan of the
# uploads table. The endpoint is public and unauthenticated, and was taking
# ~2.3M requests/day, which saturated the database and returned ~480k 503s/day.
class AddIndexToUploadsOriginalUrl < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :uploads, :original_url, algorithm: :concurrently
  end
end
