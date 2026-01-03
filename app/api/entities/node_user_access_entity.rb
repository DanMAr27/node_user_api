# app/api/entities/node_user_access_entity.rb
module Entities
  class NodeUserAccessEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :user_id, documentation: { type: "Integer", desc: "ID del usuario" }
    expose :organizational_node_id, documentation: { type: "Integer", desc: "ID del nodo" }
    expose :granted_at, format_with: :iso_timestamp, documentation: { type: "String", desc: "Fecha de otorgamiento" }
    expose :granted_by_id, documentation: { type: "Integer", desc: "ID del usuario que otorgó el acceso" }

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados
    expose :days_since_granted do |access|
      access.days_since_granted
    end

    expose :recently_granted do |access|
      access.recently_granted?
    end

    # Información del usuario (opcional)
    expose :user, using: Entities::UserEntity, if: { include_user: true }

    # Información del nodo (opcional)
    expose :organizational_node, using: Entities::OrganizationalNodeEntity, if: { include_node: true }

    # Información de quien otorgó el acceso (opcional)
    expose :granted_by, using: Entities::UserEntity, if: { include_granted_by: true }

    # Métricas de cobertura (opcional)
    expose :coverage, if: { include_coverage: true } do |access|
      {
        covers_vehicles: access.covers_vehicles?,
        covered_vehicles_count: access.covered_vehicles_count,
        covered_nodes_count: access.covered_nodes_count
      }
    end
  end
end
