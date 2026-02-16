class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :hca_id
      t.text :hca_access_token
      t.string :email
      t.string :name
      t.boolean :is_admin, default: false, null: false

      t.timestamps
    end
    add_index :users, :hca_id, unique: true
  end
end
