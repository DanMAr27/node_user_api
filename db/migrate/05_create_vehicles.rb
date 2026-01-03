# db/migrate/20250102000003_create_vehicles.rb
class CreateVehicles < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicles do |t|
      t.string :plate, null: false, limit: 20
      t.string :brand, limit: 50
      t.string :model, limit: 50
      t.integer :year
      t.string :vin, limit: 17
      t.text :description

      # Asignación a nodo organizacional
      t.references :organizational_node, null: false, foreign_key: true, index: true

      # Soft delete
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :vehicles, :plate, unique: true
    add_index :vehicles, :vin, unique: true, where: "vin IS NOT NULL"
    add_index :vehicles, [ :organizational_node_id, :discarded_at ]
  end
end
