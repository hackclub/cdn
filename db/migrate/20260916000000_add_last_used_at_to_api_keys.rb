class AddLastUsedAtToAPIKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :api_keys, :last_used_at, :datetime
  end
end
