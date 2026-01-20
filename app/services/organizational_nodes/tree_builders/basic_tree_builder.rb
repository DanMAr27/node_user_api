# app/services/organizational_nodes/tree_builders/basic_tree_builder.rb
module OrganizationalNodes
  module TreeBuilders
    class BasicTreeBuilder
      # Construye una representación básica en árbol de la jerarquía organizacional
      # Optimizado para performance: 1-2 queries totales
      # Compatible con Grape Entity (retorna hashes)

      def initialize(root_node = nil, options = {})
        @root_node = root_node
        @max_depth = options[:max_depth]
        @user = options[:user]
      end

      def call
        nodes = load_all_nodes
        return [] if nodes.empty?

        build_tree_in_memory(nodes)
      end

      private

      # Carga todos los nodos necesarios en UNA SOLA query optimizada
      def load_all_nodes
        relation = if @root_node.present?
          @root_node.self_and_descendants
        else
          OrganizationalNode.all
        end

        # Query optimizada con includes para evitar N+1
        relation
          .kept
          .includes(:organizational_level)
          .order(:ancestry, :name)
          .to_a  # Cargar todo en memoria
      end

      # Construye el árbol en memoria usando hash lookup (O(n) complexity)
      def build_tree_in_memory(nodes)
        nodes_by_id = {}
        children_by_parent = Hash.new { |h, k| h[k] = [] }

        # Primera pasada: crear estructura de datos para cada nodo
        nodes.each do |node|
          node_data = build_node_data(node)
          nodes_by_id[node.id] = node_data
          children_by_parent[node.parent_id] << node_data
        end

        # Segunda pasada: asignar hijos a cada nodo
        nodes_by_id.each do |id, node_data|
          node_data[:children] = children_by_parent[id]
        end

        # Retornar solo los nodos raíz
        if @root_node.present?
          [ nodes_by_id[@root_node.id] ]
        else
          children_by_parent[nil]
        end
      end

      # Construye la estructura de datos para un nodo
      # Formato compatible con OrganizationalNodeTreeUiEntity
      def build_node_data(node)
        {
          id: node.id,
          name: node.name,
          parent_id: node.parent_id,
          level: {
            name: node.organizational_level.name
          },
          counts: {
            direct_vehicles: node.vehicles_count
          },
          children: []  # Se llenará en build_tree_in_memory
        }
      end
    end
  end
end
