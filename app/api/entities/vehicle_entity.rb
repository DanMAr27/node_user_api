# app/api/entities/vehicle_entity.rb
module Entities
  class VehicleEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :plate, documentation: { type: "String", desc: "Matrícula del vehículo" }
    expose :brand, documentation: { type: "String", desc: "Marca del vehículo" }
    expose :model, documentation: { type: "String", desc: "Modelo del vehículo" }
    expose :year, documentation: { type: "Integer", desc: "Año del vehículo" }
    expose :vin, documentation: { type: "String", desc: "VIN (Vehicle Identification Number)" }
    expose :description, documentation: { type: "String", desc: "Descripción del vehículo" }

    # Relación con nodo organizacional
    expose :organizational_node_id, documentation: { type: "Integer", desc: "ID del nodo organizacional" }

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados
    expose :full_name do |vehicle|
      vehicle.full_name
    end

    expose :age do |vehicle|
      vehicle.year.present? ? Date.current.year - vehicle.year : nil
    end

    # Información de ubicación
    expose :location, if: { include_location: true } do |vehicle|
      node = vehicle.organizational_node
      {
        node_id: node.id,
        node_name: node.name,
        node_code: node.code,
        full_path: node.full_path,
        level: {
          id: node.organizational_level.id,
          name: node.organizational_level.name,
          order: node.organizational_level.level_order
        }
      }
    end

    # Relación completa con nodo (opcional)
    expose :organizational_node, using: Entities::OrganizationalNodeEntity, if: { include_node: true }
  end
end
