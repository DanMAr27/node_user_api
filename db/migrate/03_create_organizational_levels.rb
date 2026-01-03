# db/migrate/20250102000001_create_organizational_levels.rb
class CreateOrganizationalLevels < ActiveRecord::Migration[7.0]
  def change
    create_table :organizational_levels do |t|
      t.string :name, null: false, limit: 100
      t.text :description
      t.integer :level_order, null: false
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :organizational_levels, :level_order, unique: true
    add_index :organizational_levels, :name
  end
end
