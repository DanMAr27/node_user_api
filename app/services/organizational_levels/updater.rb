# app/services/organizational_levels/updater.rb
module OrganizationalLevels
  class Updater
    # Inicializa el servicio con el nivel y los nuevos parámetros
    # @param level [OrganizationalLevel] Nivel a actualizar
    # @param params [Hash] Nuevos atributos
    def initialize(level, params)
      @level = level
      @params = params
      @errors = []
    end

    # Ejecuta la actualización
    # @return [Boolean]
    def call
      validate_level
      return false if @errors.any?

      validate_params
      return false if @errors.any?

      update_level
      @errors.empty?
    end

    attr_reader :level, :errors

    def success?
      @errors.empty?
    end

    private

    # Valida que el nivel exista y esté activo
    def validate_level
      if @level.nil?
        @errors << "Nivel no encontrado"
      elsif @level.discarded?
        @errors << "No se puede actualizar un nivel eliminado"
      end
    end

    # Valida los parámetros de actualización
    def validate_params
      if @params[:name].present? && @params[:name].blank?
        @errors << "El nombre no puede estar vacío"
      end

      # Si se cambia el order, validar que no exista otro nivel con ese orden
      if @params[:level_order].present? && @params[:level_order] != @level.level_order
        if OrganizationalLevel.where.not(id: @level.id).exists?(level_order: @params[:level_order])
          @errors << "Ya existe otro nivel con el orden #{@params[:level_order]}"
        end
      end

      # IMPORTANTE: Si se cambia el order de un nivel, verificar impacto en la jerarquía
      if @params[:level_order].present? && @params[:level_order] != @level.level_order
        if @level.has_nodes?
          @errors << "No se puede cambiar el orden de un nivel que tiene nodos asignados"
        end
      end
    end

    # Actualiza el nivel
    def update_level
      update_params = {}
      update_params[:name] = @params[:name] if @params[:name].present?
      update_params[:description] = @params[:description] if @params.key?(:description)
      update_params[:level_order] = @params[:level_order] if @params[:level_order].present?

      unless @level.update(update_params)
        @errors.concat(@level.errors.full_messages)
      end
    rescue StandardError => e
      @errors << "Error al actualizar el nivel: #{e.message}"
    end
  end
end
