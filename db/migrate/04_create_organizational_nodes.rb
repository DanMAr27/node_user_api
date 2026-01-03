# db/migrate/20250102000002_create_organizational_nodes.rb
class CreateOrganizationalNodes < ActiveRecord::Migration[7.0]
  def change
    create_table :organizational_nodes do |t|
      t.string :name, null: false, limit: 100
      t.text :description
      t.string :code, limit: 50
      t.references :organizational_level, null: false, foreign_key: true, index: true

      # Ancestry para jerarquía
      t.string :ancestry, index: true
      t.integer :ancestry_depth, default: 0

      # Soft delete
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :organizational_nodes, :name
    add_index :organizational_nodes, :code, unique: true, where: "code IS NOT NULL"
    add_index :organizational_nodes, [ :organizational_level_id, :name ]
  end
end
