class FixOrganizationalLevelsIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing index which enforces global uniqueness
    remove_index :organizational_levels, :level_order

    # Add a partial index that enforces uniqueness only for active (non-deleted) records
    add_index :organizational_levels, :level_order, unique: true, where: "discarded_at IS NULL"
  end
end
