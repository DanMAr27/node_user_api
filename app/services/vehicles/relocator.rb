# app/services/vehicles/relocator.rb
module Vehicles
  class Relocator
    # Reubica un vehículo a otro nodo organizacional
    # IMPORTANTE: Este servicio implementa la lógica de negocio para mover vehículos
    # manteniendo la integridad de la visibilidad
    #
    # @param vehicle [Vehicle] Vehículo a reubicar
    # @param new_node_id [Integer] ID del nuevo nodo destino
    # @param reason [String] Razón de la reubicación (opcional, para auditoría)
    def initialize(vehicle, new_node_id, reason: nil)
      @vehicle = vehicle
      @new_node_id = new_node_id
      @reason = reason
      @errors = []
      @old_node = nil
      @new_node = nil
    end

    def call
      validate_vehicle
      return false if @errors.any?

      validate_new_node
      return false if @errors.any?

      validate_relocation
      return false if @errors.any?

      relocate_vehicle
      @errors.empty?
    end

    attr_reader :vehicle, :errors, :old_node, :new_node

    def success?
      @errors.empty?
    end

    # Retorna información sobre la reubicación
    def relocation_info
      return nil unless success?

      {
        vehicle_id: @vehicle.id,
        vehicle_plate: @vehicle.plate,
        from_node: {
          id: @old_node.id,
          name: @old_node.name,
          path: @old_node.full_path
        },
        to_node: {
          id: @new_node.id,
          name: @new_node.name,
          path: @new_node.full_path
        },
        reason: @reason,
        relocated_at: Time.current
      }
    end

    private

    def validate_vehicle
      if @vehicle.nil?
        @errors << "Vehículo no encontrado"
        return
      end

      if @vehicle.discarded?
        @errors << "No se puede reubicar un vehículo eliminado"
        return
      end

      @old_node = @vehicle.organizational_node
    end

    def validate_new_node
      if @new_node_id.blank?
        @errors << "El nodo destino es obligatorio"
        return
      end

      # Validar que no sea el mismo nodo
      if @new_node_id == @vehicle.organizational_node_id
        @errors << "El vehículo ya está asignado a este nodo"
        return
      end

      # Validar que el nuevo nodo exista y esté activo
      @new_node = OrganizationalNode.find_by(id: @new_node_id)

      if @new_node.nil?
        @errors << "El nodo destino no existe"
      elsif @new_node.discarded?
        @errors << "El nodo destino está eliminado"
      end
    end

    # VALIDACIONES DE NEGOCIO para la reubicación
    def validate_relocation
      # REGLA: Preferiblemente los vehículos se asignan al nivel más bajo
      # Pero no lo hacemos obligatorio en el POC para mayor flexibilidad

      # Podríamos agregar validaciones adicionales aquí:
      # - Verificar que el usuario tenga permisos en el nodo destino
      # - Validar reglas de negocio específicas (ej: solo ciertos tipos de vehículos en ciertos nodos)
      # - Verificar capacidad del nodo destino

      # Por ahora, permitimos cualquier reubicación entre nodos activos
    end

    # Realiza la reubicación
    def relocate_vehicle
      ActiveRecord::Base.transaction do
        # Actualizar el nodo del vehículo
        @vehicle.update!(organizational_node_id: @new_node_id)

        # Aquí podríamos agregar un registro de auditoría si fuera necesario
        # AuditLog.create!(
        #   action: 'vehicle_relocated',
        #   vehicle: @vehicle,
        #   old_node: @old_node,
        #   new_node: @new_node,
        #   reason: @reason
        # )
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
    rescue StandardError => e
      @errors << "Error al reubicar el vehículo: #{e.message}"
    end
  end
end
