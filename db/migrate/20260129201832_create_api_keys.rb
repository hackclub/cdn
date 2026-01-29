class CreateAPIKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.string :name, null: false
      t.text :token_ciphertext, null: false     # Lockbox encrypted token
      t.string :token_bidx, null: false         # Blind index for lookup
      t.boolean :revoked, default: false, null: false
      t.datetime :revoked_at
      t.timestamps

      t.index :token_bidx, unique: true
      t.index [:user_id, :revoked]
    end
  end
end
