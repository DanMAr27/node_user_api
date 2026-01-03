# app/api/entities/organizational_node_entity.rb
module Entities
  class OrganizationalNodeEntity < BaseEntity
    # Campos básicos
    expose_id
    expose :name, documentation: { type: "String", desc: "Nombre del nodo" }
    expose :code, documentation: { type: "String", desc: "Código único del nodo" }
    expose :description, documentation: { type: "String", desc: "Descripción del nodo" }

    # Relación con nivel
    expose :organizational_level_id, documentation: { type: "Integer", desc: "ID del nivel organizacional" }
    expose :organizational_level, using: Entities::OrganizationalLevelEntity, if: { include_level: true }

    # Jerarquía
    expose :parent_id, documentation: { type: "Integer", desc: "ID del nodo padre" }
    expose :ancestry, documentation: { type: "String", desc: "Ruta de ancestros (Ancestry gem)" }
    expose :ancestry_depth, documentation: { type: "Integer", desc: "Profundidad en el árbol" }

    # Timestamps
    expose_timestamps

    # Soft delete
    expose_soft_delete

    # Campos calculados
    expose :is_root do |node|
      node.root_node?
    end

    expose :is_leaf do |node|
      node.leaf_node?
    end

    expose :full_path, if: { include_path: true } do |node|
      node.full_path
    end

    expose :full_code, if: { include_full_code: true } do |node|
      node.full_code
    end

    # Contadores opcionales
    expose :vehicles_count, if: { include_counts: true } do |node|
      node.vehicles_count
    end

    expose :total_vehicles_count, if: { include_counts: true } do |node|
      node.total_vehicles_count
    end

    expose :children_count, if: { include_counts: true } do |node|
      node.children_count
    end

    expose :descendants_count, if: { include_counts: true } do |node|
      node.descendants_count
    end

    # Relaciones opcionales (usan entity simplificada para evitar recursión infinita)
    expose :parent, using: Entities::OrganizationalNodeSimpleEntity, if: { include_parent: true }

    expose :children, using: Entities::OrganizationalNodeSimpleEntity, if: { include_children: true }

    expose :vehicles, using: Entities::VehicleEntity, if: { include_vehicles: true }
  end
end
