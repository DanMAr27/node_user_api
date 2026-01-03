# app/services/organizational_nodes/tree_builder.rb
module OrganizationalNodes
  class TreeBuilder
    # Construye una representación en árbol de la jerarquía organizacional
    # @param root_node [OrganizationalNode, nil] Nodo raíz (si nil, construye el árbol completo)
    # @param options [Hash] Opciones de construcción
    #   - :include_vehicles [Boolean] Incluir vehículos en cada nodo (default: false)
    #   - :include_counts [Boolean] Incluir contadores (vehículos, hijos) (default: true)
    #   - :max_depth [Integer] Profundidad máxima del árbol (default: nil = sin límite)
    #   - :user [User] Usuario para filtrar por visibilidad (default: nil = todos)
    def initialize(root_node = nil, options = {})
      @root_node = root_node
      @options = default_options.merge(options)
      @tree = []
      @errors = []
    end

    def call
      validate_options
      return [] if @errors.any?

      build_tree
      @tree
    end

    attr_reader :tree, :errors

    def success?
      @errors.empty?
    end

    private

    def default_options
      {
        include_vehicles: false,
        include_counts: true,
        max_depth: nil,
        user: nil
      }
    end

    def validate_options
      if @root_node.present? && @root_node.discarded?
        @errors << "El nodo raíz está eliminado"
      end

      if @options[:max_depth].present? && @options[:max_depth] < 0
        @errors << "La profundidad máxima debe ser mayor o igual a 0"
      end
    end

    # Construye el árbol jerárquico
    def build_tree
      if @root_node.present?
        # Construir árbol desde un nodo específico
        @tree = build_node_tree(@root_node, 0)
      else
        # Construir árbol completo desde todos los nodos raíz
        roots = base_relation.where(ancestry: nil).order(:name)
        @tree = roots.map { |root| build_node_tree(root, 0) }
      end
    end

    # Construye recursivamente el árbol para un nodo
    # @param node [OrganizationalNode] Nodo actual
    # @param current_depth [Integer] Profundidad actual
    # @return [Hash] Representación del nodo con sus hijos
    def build_node_tree(node, current_depth)
      node_data = {
        id: node.id,
        name: node.name,
        code: node.code,
        description: node.description,
        level: {
          id: node.organizational_level.id,
          name: node.organizational_level.name,
          order: node.organizational_level.level_order
        },
        depth: current_depth,
        is_root: node.root_node?,
        is_leaf: node.leaf_node?,
        children: []
      }

      # Agregar contadores si está habilitado
      if @options[:include_counts]
        node_data[:counts] = {
          direct_vehicles: node.vehicles_count,
          total_vehicles: node.total_vehicles_count,
          direct_children: node.children_count,
          total_descendants: node.descendants_count
        }
      end

      # Agregar vehículos si está habilitado
      if @options[:include_vehicles]
        node_data[:vehicles] = node.vehicles.map do |vehicle|
          {
            id: vehicle.id,
            plate: vehicle.plate,
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year
          }
        end
      end

      # Construir hijos recursivamente si no hemos alcanzado la profundidad máxima
      if @options[:max_depth].nil? || current_depth < @options[:max_depth]
        # Ancestry usa children, no parent_id
        children = node.children.kept.order(:name)

        # Aplicar filtro de usuario si existe
        if @options[:user].present?
          accessible_node_ids = @options[:user].visible_nodes.pluck(:id)
          children = children.where(id: accessible_node_ids)
        end

        node_data[:children] = children.map do |child|
          build_node_tree(child, current_depth + 1)
        end
      end

      node_data
    end

    # Obtiene la relación base de nodos según las opciones
    def base_relation
      relation = OrganizationalNode.kept.includes(:organizational_level)

      # Filtrar por visibilidad si se especifica un usuario
      if @options[:user].present?
        accessible_node_ids = @options[:user].visible_nodes.pluck(:id)
        relation = relation.where(id: accessible_node_ids)
      end

      relation
    end

    # Método público adicional: Construir árbol en formato flat (para UI)
    # Retorna un array plano con información de indentación
    def self.build_flat_tree(root_node = nil, options = {})
      builder = new(root_node, options)
      tree = builder.call
      flatten_tree(tree)
    end

    # Convierte el árbol anidado en un array plano
    def self.flatten_tree(tree, level = 0, result = [])
      tree = [ tree ] unless tree.is_a?(Array)

      tree.each do |node|
        result << {
          **node.except(:children),
          indent_level: level
        }

        flatten_tree(node[:children], level + 1, result) if node[:children].any?
      end

      result
    end
  end
end
