# app/services/user_access/visibility_calculator.rb
module UserAccess
  class VisibilityCalculator
    # Calcula la visibilidad completa de un usuario
    # Este servicio es fundamental para determinar qué puede ver cada usuario
    # basándose en la herencia jerárquica de nodos
    #
    # @param user [User] Usuario para calcular visibilidad
    def initialize(user)
      @user = user
      @errors = []
      @calculation_result = nil
    end

    # Calcula la visibilidad completa
    # @return [Hash] Resultado del cálculo
    def call
      validate_user
      return nil if @errors.any?

      calculate_visibility
      @calculation_result
    end

    # Verifica si el usuario puede ver un nodo específico
    # @param node [OrganizationalNode]
    # @return [Boolean]
    def can_see_node?(node)
      return false if node.nil? || @user.nil?

      # Obtener nodos accesibles del usuario
      accessible_node_ids = @user.accessible_nodes.pluck(:id)

      # El usuario puede ver el nodo si:
      # 1. Tiene acceso directo al nodo
      # 2. Tiene acceso a algún ancestro del nodo
      node_and_ancestor_ids = node.self_and_ancestors.pluck(:id)
      (accessible_node_ids & node_and_ancestor_ids).any?
    end

    # Verifica si el usuario puede ver un vehículo
    # @param vehicle [Vehicle]
    # @return [Boolean]
    def can_see_vehicle?(vehicle)
      return false if vehicle.nil? || @user.nil?
      can_see_node?(vehicle.organizational_node)
    end

    # Calcula el alcance de visibilidad (scope breadth)
    # Retorna métricas sobre cuánto puede ver el usuario
    def visibility_scope
      calculate_visibility unless @calculation_result

      {
        direct_nodes: @calculation_result[:direct_nodes_count],
        visible_nodes: @calculation_result[:visible_nodes_count],
        visible_vehicles: @calculation_result[:visible_vehicles_count],
        coverage_percentage: calculate_coverage_percentage,
        levels_coverage: calculate_levels_coverage
      }
    end

    # Obtiene los nodos visibles organizados por nivel
    # @return [Hash] { level_name => [nodes] }
    def visible_nodes_by_level
      calculate_visibility unless @calculation_result

      visible_nodes = @calculation_result[:visible_nodes]
      visible_nodes.group_by { |node| node.organizational_level.name }
    end

    # Obtiene estadísticas de vehículos visibles
    def visible_vehicles_statistics
      calculate_visibility unless @calculation_result

      visible_vehicles = @calculation_result[:visible_vehicles]

      {
        total: visible_vehicles.count,
        by_brand: visible_vehicles.group_by(&:brand).transform_values(&:count),
        by_year: visible_vehicles.group_by(&:year).transform_values(&:count),
        by_node: visible_vehicles.group_by { |v| v.organizational_node.name }.transform_values(&:count),
        average_age: calculate_average_vehicle_age(visible_vehicles)
      }
    end

    # Detecta posibles problemas de visibilidad
    # @return [Array<Hash>] Lista de problemas detectados
    def detect_visibility_issues
      issues = []

      calculate_visibility unless @calculation_result

      # Issue 1: Usuario sin accesos
      if @calculation_result[:direct_nodes_count] == 0
        issues << {
          type: :no_access,
          severity: :high,
          message: "El usuario no tiene ningún acceso asignado"
        }
      end

      # Issue 2: Usuario con acceso pero sin vehículos visibles
      if @calculation_result[:direct_nodes_count] > 0 && @calculation_result[:visible_vehicles_count] == 0
        issues << {
          type: :no_vehicles,
          severity: :medium,
          message: "El usuario tiene accesos pero no hay vehículos en los nodos asignados"
        }
      end

      # Issue 3: Detectar accesos potencialmente redundantes
      redundant = detect_redundant_accesses
      if redundant.any?
        issues << {
          type: :redundant_access,
          severity: :low,
          message: "Se detectaron #{redundant.count} acceso(s) potencialmente redundante(s)",
          details: redundant
        }
      end

      issues
    end

    # Compara visibilidad con otro usuario
    # Útil para auditoría y análisis
    # @param other_user [User]
    # @return [Hash]
    def compare_with(other_user)
      my_visibility = calculate_visibility
      other_calculator = self.class.new(other_user)
      other_visibility = other_calculator.calculate_visibility

      {
        user1: {
          name: @user.full_name,
          nodes: my_visibility[:visible_nodes_count],
          vehicles: my_visibility[:visible_vehicles_count]
        },
        user2: {
          name: other_user.full_name,
          nodes: other_visibility[:visible_nodes_count],
          vehicles: other_visibility[:visible_vehicles_count]
        },
        shared_nodes: calculate_shared_nodes(my_visibility[:visible_nodes], other_visibility[:visible_nodes]),
        shared_vehicles: calculate_shared_vehicles(my_visibility[:visible_vehicles], other_visibility[:visible_vehicles])
      }
    end

    attr_reader :errors

    def success?
      @errors.empty?
    end

    private

    def validate_user
      if @user.nil?
        @errors << "Usuario no encontrado"
      elsif @user.discarded?
        @errors << "Usuario eliminado"
      end
    end

    # MÉTODO PRINCIPAL: Calcula toda la visibilidad del usuario
    def calculate_visibility
      # 1. Obtener nodos con acceso directo
      direct_nodes = @user.accessible_nodes.to_a

      # 2. Expandir a todos los nodos visibles (con descendientes)
      visible_node_ids = direct_nodes.flat_map do |node|
        node.self_and_descendants.pluck(:id)
      end.uniq

      visible_nodes = OrganizationalNode.where(id: visible_node_ids).includes(:organizational_level)

      # 3. Obtener todos los vehículos en esos nodos
      visible_vehicles = Vehicle.where(organizational_node_id: visible_node_ids).includes(:organizational_node)

      @calculation_result = {
        direct_nodes: direct_nodes,
        direct_nodes_count: direct_nodes.count,
        visible_nodes: visible_nodes.to_a,
        visible_nodes_count: visible_nodes.count,
        visible_vehicles: visible_vehicles.to_a,
        visible_vehicles_count: visible_vehicles.count,
        calculated_at: Time.current
      }
    end

    # Calcula el porcentaje de cobertura respecto al total del sistema
    def calculate_coverage_percentage
      total_nodes = OrganizationalNode.count
      return 0 if total_nodes == 0

      visible_count = @calculation_result[:visible_nodes_count]
      ((visible_count.to_f / total_nodes) * 100).round(2)
    end

    # Calcula la cobertura por nivel
    def calculate_levels_coverage
      visible_nodes = @calculation_result[:visible_nodes]

      OrganizationalLevel.ordered.map do |level|
        total_in_level = level.organizational_nodes.count
        visible_in_level = visible_nodes.count { |n| n.organizational_level_id == level.id }

        {
          level_name: level.name,
          level_order: level.level_order,
          total_nodes: total_in_level,
          visible_nodes: visible_in_level,
          percentage: total_in_level > 0 ? ((visible_in_level.to_f / total_in_level) * 100).round(2) : 0
        }
      end
    end

    # Detecta accesos redundantes
    def detect_redundant_accesses
      redundant = []
      direct_nodes = @calculation_result[:direct_nodes]

      direct_nodes.each do |node|
        # Verificar si algún otro acceso directo es ancestro de este nodo
        other_nodes = direct_nodes - [ node ]

        other_nodes.each do |other_node|
          if node.descendant_of?(other_node)
            redundant << {
              node_id: node.id,
              node_name: node.name,
              made_redundant_by: {
                node_id: other_node.id,
                node_name: other_node.name
              }
            }
          end
        end
      end

      redundant
    end

    def calculate_average_vehicle_age(vehicles)
      current_year = Date.current.year
      years = vehicles.map(&:year).compact

      return 0 if years.empty?

      ages = years.map { |year| current_year - year }
      (ages.sum.to_f / ages.size).round(1)
    end

    def calculate_shared_nodes(nodes1, nodes2)
      ids1 = nodes1.map(&:id)
      ids2 = nodes2.map(&:id)
      (ids1 & ids2).count
    end

    def calculate_shared_vehicles(vehicles1, vehicles2)
      ids1 = vehicles1.map(&:id)
      ids2 = vehicles2.map(&:id)
      (ids1 & ids2).count
    end
  end
end
