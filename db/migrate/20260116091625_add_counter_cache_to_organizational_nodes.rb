class AddCounterCacheToOrganizationalNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :organizational_nodes, :vehicles_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        # Populate existing counter cache data
        execute <<-SQL
          UPDATE organizational_nodes
          SET vehicles_count = (
            SELECT COUNT(*)
            FROM vehicles
            WHERE vehicles.organizational_node_id = organizational_nodes.id
          )
        SQL
      end
    end

    add_index :organizational_nodes, :vehicles_count
  end
end
