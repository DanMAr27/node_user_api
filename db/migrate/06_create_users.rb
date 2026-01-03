# db/migrate/20250102000004_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, limit: 100
      t.string :first_name, null: false, limit: 50
      t.string :last_name, null: false, limit: 50
      t.string :phone, limit: 20

      # Soft delete
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, [ :first_name, :last_name ]
  end
end
