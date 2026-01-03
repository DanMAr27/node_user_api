# app/models/concerns/hierarchy_queryable.rb
module HierarchyQueryable
  extend ActiveSupport::Concern

  included do
    # Ancestry ya provee: parent, children, ancestors, descendants, siblings, etc.
    # Este concern agrega métodos adicionales útiles
  end

  # Métodos de instancia

  # Obtener todos los ancestros incluyendo el nodo actual
  def self_and_ancestors
    ancestors.to_a.push(self)
  end

  # Obtener todos los descendientes incluyendo el nodo actual
  def self_and_descendants
    descendants.to_a.push(self)
  end

  # Obtener toda la rama (ancestros + self + descendientes)
  def branch
    (ancestors.to_a + [ self ] + descendants.to_a).uniq
  end

  # Verificar si es nodo raíz
  def root_node?
    parent_id.nil?
  end

  # Verificar si es nodo hoja (sin hijos)
  def leaf_node?
    children.empty?
  end

  # Obtener el nivel de profundidad (0 = raíz)
  def depth_level
    ancestry_depth || 0
  end

  # Obtener la ruta completa de nombres desde la raíz
  def path_names
    self_and_ancestors.map(&:name)
  end

  # Obtener la ruta completa como string
  def full_path(separator: " > ")
    path_names.join(separator)
  end

  # Verificar si un nodo es descendiente de otro
  def descendant_of?(node)
    return false if node.nil?
    ancestor_ids.include?(node.id)
  end

  # Verificar si un nodo es ancestro de otro
  def ancestor_of?(node)
    return false if node.nil?
    node.descendant_of?(self)
  end

  # Métodos de clase
  module ClassMethods
    # Obtener todos los nodos raíz
    def roots
      where(ancestry: nil)
    end

    # Obtener nodos hojas (sin hijos)
    def leaves
      where.not(id: select(:parent_id).distinct)
    end

    # Construir árbol jerárquico como hash
    def arrange_as_tree
      arrange
    end

    # Obtener nodos por profundidad
    def at_depth(depth)
      where(ancestry_depth: depth)
    end

    # Obtener nodos de un nivel específico
    def by_level(level_id)
      where(organizational_level_id: level_id)
    end
  end
end
