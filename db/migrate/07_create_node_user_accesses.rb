# db/migrate/20250102000005_create_node_user_accesses.rb
class CreateNodeUserAccesses < ActiveRecord::Migration[7.0]
  def change
    create_table :node_user_accesses do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :organizational_node, null: false, foreign_key: true, index: true

      # Metadatos opcionales
      t.datetime :granted_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.references :granted_by, foreign_key: { to_table: :users }

      # Soft delete
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    # Un usuario no puede tener acceso duplicado al mismo nodo
    add_index :node_user_accesses,
              [ :user_id, :organizational_node_id ],
              unique: true,
              name: 'index_node_user_accesses_on_user_and_node'

    # Índice compuesto para queries de visibilidad
    add_index :node_user_accesses,
              [ :organizational_node_id, :user_id, :discarded_at ],
              name: 'index_node_accesses_visibility'
  end
end
