# app/api/entities/organizational_level_entity.rb
module Entities
  class OrganizationalLevelEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :name, documentation: { type: "String", desc: "Nombre del nivel" }
    expose :description, documentation: { type: "String", desc: "Descripción del nivel" }
    expose :level_order, documentation: { type: "Integer", desc: "Orden del nivel en la jerarquía" }

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados
    expose :nodes_count, if: { include_counts: true } do |level|
      level.organizational_nodes.count
    end

    expose :is_first_level do |level|
      level.first_level?
    end

    expose :is_last_level do |level|
      level.last_level?
    end

    # Relaciones opcionales
    expose :nodes, using: Entities::OrganizationalNodeEntity, if: { include_nodes: true } do |level|
      level.organizational_nodes
    end
  end
end
