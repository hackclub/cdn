class AddQuotaPolicyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :quota_policy, :string
  end
end
