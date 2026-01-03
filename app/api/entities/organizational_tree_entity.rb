# app/api/entities/organizational_tree_entity.rb
module Entities
  class OrganizationalTreeEntity < BaseEntity
    # Esta entity se usa para representar el árbol jerárquico completo
    # Usa un formato simplificado y recursivo

    expose :id
    expose :name
    expose :code
    expose :description

    # Información del nivel
    expose :level do |node, options|
      {
        id: node.dig(:level, :id),
        name: node.dig(:level, :name),
        order: node.dig(:level, :order)
      }
    end

    # Información jerárquica
    expose :depth
    expose :is_root
    expose :is_leaf

    # Contadores (si están incluidos)
    expose :counts, if: ->(node, options) { node.key?(:counts) }

    # Vehículos (si están incluidos)
    expose :vehicles, if: ->(node, options) { node.key?(:vehicles) }

    # Hijos (recursivo)
    expose :children, using: Entities::OrganizationalTreeEntity do |node|
      node[:children] || []
    end
  end
end
