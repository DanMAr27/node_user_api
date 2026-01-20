# app/services/organizational_levels/creator.rb
module OrganizationalLevels
  class Creator
    # Inicializa el servicio con los parámetros necesarios
    # @param params [Hash] Atributos del nivel organizacional
    # @return [Creator]
    def initialize(params)
      @params = params
      @level = nil
      @errors = []
    end

    # Ejecuta la creación del nivel organizacional
    # @return [Boolean] true si fue exitoso, false si hubo errores
    def call
      validate_params
      return false if @errors.any?

      create_level
      @errors.empty?
    end

    # Retorna el nivel creado
    # @return [OrganizationalLevel, nil]
    attr_reader :level

    # Retorna los errores acumulados
    # @return [Array<String>]
    attr_reader :errors

    # Verifica si el servicio fue exitoso
    # @return [Boolean]
    def success?
      @errors.empty? && @level.present? && @level.persisted?
    end

    private

    # Valida los parámetros antes de crear
    def validate_params
      if @params[:name].blank?
        @errors << "El nombre es obligatorio"
      end

      if @params[:level_order].present? && (!@params[:level_order].is_a?(Integer) || @params[:level_order] < 1)
        @errors << "El orden del nivel debe ser un número entero positivo"
      end

      # Validar que no exista otro nivel con el mismo orden
      if @params[:level_order].present?
        if OrganizationalLevel.kept.exists?(level_order: @params[:level_order])
          @errors << "Ya existe un nivel con el orden #{@params[:level_order]}"
        end
      end
    end

    # Crea el nivel organizacional
    def create_level
      @level = OrganizationalLevel.new(
        name: @params[:name],
        description: @params[:description],
        level_order: @params[:level_order]
      )

      unless @level.save
        @errors.concat(@level.errors.full_messages)
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
    rescue StandardError => e
      @errors << "Error al crear el nivel: #{e.message}"
    end
  end
end
