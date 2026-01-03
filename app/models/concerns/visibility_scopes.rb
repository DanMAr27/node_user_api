# app/models/concerns/visibility_scopes.rb
module VisibilityScopes
  extend ActiveSupport::Concern

  included do
    # Scope para filtrar por nodos específicos
    scope :in_nodes, ->(node_ids) {
      where(organizational_node_id: node_ids)
    }

    # Scope para filtrar por una rama jerárquica completa
    scope :in_branch, ->(node) {
      return none if node.nil?

      # Obtener el nodo y todos sus descendientes
      node_ids = node.self_and_descendants.pluck(:id)
      in_nodes(node_ids)
    }

    # Scope para filtrar por múltiples ramas
    scope :in_branches, ->(nodes) {
      return none if nodes.blank?

      node_ids = nodes.flat_map { |node| node.self_and_descendants.pluck(:id) }.uniq
      in_nodes(node_ids)
    }

    # Scope para filtrar por nivel organizacional
    scope :by_organizational_level, ->(level_id) {
      joins(:organizational_node).where(organizational_nodes: { organizational_level_id: level_id })
    }
  end

  module ClassMethods
    # Obtener registros visibles para un usuario basado en sus nodos asignados
    def visible_for_user(user)
      return none if user.nil?

      # Obtener nodos a los que el usuario tiene acceso
      accessible_nodes = user.accessible_nodes
      return none if accessible_nodes.empty?

      # Retornar todos los registros en las ramas de esos nodos
      in_branches(accessible_nodes)
    end

    # Obtener registros por nodo específico (sin herencia)
    def directly_in_node(node)
      where(organizational_node_id: node.id)
    end

    # Contar registros por nodo (agrupados)
    def count_by_node
      group(:organizational_node_id).count
    end

    # Contar registros por nivel organizacional
    def count_by_level
      joins(:organizational_node)
        .group("organizational_nodes.organizational_level_id")
        .count
    end
  end
end
