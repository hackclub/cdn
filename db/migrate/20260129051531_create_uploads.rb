class CreateUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :uploads, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }

      # Upload source tracking
      t.string :provenance, null: false        # enum: slack, web, api, rescued

      # For rescued files from old hel1 bucket
      t.string :original_url                   # Old CDN URL to fixup

      t.timestamps

      t.index [:user_id, :created_at]
      t.index :created_at
      t.index :provenance
    end
  end
end
