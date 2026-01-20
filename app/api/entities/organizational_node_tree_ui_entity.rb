# app/api/entities/organizational_node_tree_ui_entity.rb
module Entities
  class OrganizationalNodeTreeUiEntity < BaseEntity
    expose :id
    expose :name
    expose :parent_id
    # Solo el nombre del nivel para el badge
    expose :level_name do |node|
      if node.is_a?(Hash)
        node.dig(:level, :name)
      else
        node.organizational_level.name
      end
    end
    # CRÍTICO: Contador de vehículos para indicador visual
    # Permite saber si el nodo puede ser eliminado sin hacer request adicional
    expose :vehicles_count do |node|
      if node.is_a?(Hash)
        node.dig(:counts, :direct_vehicles) || 0
      else
        0
      end
    end
    # Hijos recursivos (misma entity)
    expose :children, using: self do |node|
      if node.is_a?(Hash)
        node[:children] || []
      else
        []
      end
    end
  end
end
