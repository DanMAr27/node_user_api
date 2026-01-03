# db/migrate/20250102000006_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Índice compuesto para queries de jerarquía con Ancestry
    add_index :organizational_nodes,
              [ :ancestry, :organizational_level_id ],
              name: 'index_nodes_on_ancestry_and_level'

    # Índice para búsquedas de vehículos por nodo y estado
    add_index :vehicles,
              [ :organizational_node_id, :plate, :discarded_at ],
              name: 'index_vehicles_node_plate_discarded'

    # Índice para filtros de nodos activos por nivel
    add_index :organizational_nodes,
              [ :organizational_level_id, :discarded_at ],
              name: 'index_nodes_level_discarded'

    # Índice para búsquedas de usuarios activos
    add_index :users,
              [ :email, :discarded_at ],
              name: 'index_users_email_discarded'
  end
end
