# app/services/organizational_levels/destroyer.rb
module OrganizationalLevels
  class Destroyer
    # Inicializa el servicio con el nivel a eliminar
    # @param level [OrganizationalLevel]
    def initialize(level)
      @level = level
      @errors = []
    end

    # Ejecuta el soft delete del nivel
    # @return [Boolean]
    def call
      validate_level
      return false if @errors.any?

      validate_can_delete
      return false if @errors.any?

      soft_delete_level
      @errors.empty?
    end

    attr_reader :level, :errors

    def success?
      @errors.empty?
    end

    private

    # Valida que el nivel exista
    def validate_level
      if @level.nil?
        @errors << "Nivel no encontrado"
      elsif @level.discarded?
        @errors << "El nivel ya está eliminado"
      end
    end

    # REGLA DE NEGOCIO: No se puede eliminar un nivel que tenga nodos asociados
    # Esto protege la integridad referencial y evita datos huérfanos
    def validate_can_delete
      if @level.has_nodes?
        active_nodes_count = @level.organizational_nodes.count
        @errors << "No se puede eliminar el nivel porque tiene #{active_nodes_count} nodo(s) asociado(s)"
      end
    end

    # Realiza el soft delete
    def soft_delete_level
      @level.discard
    rescue StandardError => e
      @errors << "Error al eliminar el nivel: #{e.message}"
    end
  end
end
