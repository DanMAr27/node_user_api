# app/services/organizational_nodes/destroyer.rb
module OrganizationalNodes
  class Destroyer
    # Elimina (soft delete) un nodo organizacional
    # @param node [OrganizationalNode]
    # @param strategy [Symbol] Estrategia de eliminación: :restrict, :cascade
    def initialize(node, strategy: :restrict)
      @node = node
      @strategy = strategy
      @errors = []
      @deleted_count = 0
    end

    def call
      validate_node
      return false if @errors.any?

      validate_can_delete
      return false if @errors.any?

      case @strategy
      when :restrict
        soft_delete_node_restricted
      when :cascade
        soft_delete_node_cascade
      else
        @errors << "Estrategia de eliminación no válida"
        return false
      end

      @errors.empty?
    end

    attr_reader :node, :errors, :deleted_count

    def success?
      @errors.empty?
    end

    private

    def validate_node
      if @node.nil?
        @errors << "Nodo no encontrado"
      elsif @node.discarded?
        @errors << "El nodo ya está eliminado"
      end
    end

    # ESTRATEGIA RESTRICT (por defecto):
    # Solo permite eliminar si NO tiene:
    # - Vehículos asignados
    # - Nodos hijos
    def validate_can_delete
      return unless @strategy == :restrict

      if @node.vehicles.exists?
        vehicles_count = @node.vehicles.count
        @errors << "No se puede eliminar el nodo porque tiene #{vehicles_count} vehículo(s) asignado(s)"
      end

      if @node.children.exists?
        children_count = @node.children.count
        @errors << "No se puede eliminar el nodo porque tiene #{children_count} nodo(s) hijo(s)"
      end
    end

    # Elimina solo el nodo (estrategia RESTRICT)
    def soft_delete_node_restricted
      @node.discard
      @deleted_count = 1
    rescue StandardError => e
      @errors << "Error al eliminar el nodo: #{e.message}"
    end

    # Elimina el nodo y TODA su rama descendiente (estrategia CASCADE)
    # CUIDADO: Esta es una operación peligrosa
    def soft_delete_node_cascade
      ActiveRecord::Base.transaction do
        # Obtener todos los nodos de la rama (incluyendo el nodo raíz)
        nodes_to_delete = @node.self_and_descendants

        # Verificar que ningún nodo tenga vehículos
        vehicle_counts = Vehicle.where(
          organizational_node_id: nodes_to_delete.pluck(:id)
        ).group(:organizational_node_id).count

        if vehicle_counts.any?
          total_vehicles = vehicle_counts.values.sum
          @errors << "No se puede eliminar la rama porque tiene #{total_vehicles} vehículo(s) asignado(s)"
          raise ActiveRecord::Rollback
        end

        # Eliminar todos los accesos de usuario asociados a estos nodos
        NodeUserAccess.where(
          organizational_node_id: nodes_to_delete.pluck(:id)
        ).discard_all

        # Eliminar todos los nodos de la rama
        nodes_to_delete.each(&:discard)
        @deleted_count = nodes_to_delete.count

      rescue StandardError => e
        @errors << "Error al eliminar la rama: #{e.message}"
        raise ActiveRecord::Rollback
      end
    end
  end
end
