# app/api/entities/user_entity.rb
module Entities
  class UserEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :email, documentation: { type: "String", desc: "Email del usuario" }
    expose :first_name, documentation: { type: "String", desc: "Nombre" }
    expose :last_name, documentation: { type: "String", desc: "Apellido" }
    expose :phone, documentation: { type: "String", desc: "Teléfono" }

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados
    expose :full_name do |user|
      user.full_name
    end

    # Información de accesos (opcional)
    expose :access_info, if: { include_access_info: true } do |user|
      {
        has_access: user.has_any_access?,
        accessible_nodes_count: user.accessible_nodes_count,
        visible_vehicles_count: user.visible_vehicles_count
      }
    end

    # Nodos accesibles (opcional)
    expose :accessible_nodes, using: Entities::OrganizationalNodeEntity, if: { include_accessible_nodes: true }
  end
end
