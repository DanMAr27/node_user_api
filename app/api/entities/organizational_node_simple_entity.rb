# app/api/entities/organizational_node_simple_entity.rb
module Entities
  # Entity simplificada para evitar recursión infinita
  # Se usa cuando se incluyen parent o children
  class OrganizationalNodeSimpleEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :name
    expose :code
    expose :description

    # Relación con nivel
    expose :organizational_level_id

    # Jerarquía básica
    expose :ancestry
    expose :ancestry_depth

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados básicos
    expose :is_root do |node|
      node.root_node?
    end

    expose :is_leaf do |node|
      node.leaf_node?
    end

    # Nivel si se solicita
    expose :organizational_level, using: Entities::OrganizationalLevelEntity, if: { include_level: true }
  end
end
