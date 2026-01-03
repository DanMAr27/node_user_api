# app/services/organizational_nodes/creator.rb
module OrganizationalNodes
  class Creator
    # Crea un nuevo nodo organizacional en la jerarquía
    # @param params [Hash] Atributos del nodo
    #   - :name [String] Nombre del nodo (obligatorio)
    #   - :organizational_level_id [Integer] ID del nivel (obligatorio)
    #   - :parent_id [Integer] ID del nodo padre (opcional para nivel 1)
    #   - :code [String] Código único del nodo (opcional)
    #   - :description [String] Descripción del nodo (opcional)
    def initialize(params)
      @params = params
      @node = nil
      @errors = []
    end

    def call
      validate_params
      return false if @errors.any?

      validate_hierarchy
      return false if @errors.any?

      create_node
      @errors.empty?
    end

    attr_reader :node, :errors

    def success?
      @errors.empty? && @node.present? && @node.persisted?
    end

    private

    # Validaciones básicas de parámetros
    def validate_params
      if @params[:name].blank?
        @errors << "El nombre es obligatorio"
      end

      if @params[:organizational_level_id].blank?
        @errors << "El nivel organizacional es obligatorio"
      end

      # Validar que el nivel exista
      @level = OrganizationalLevel.find_by(id: @params[:organizational_level_id])
      if @level.nil?
        @errors << "El nivel organizacional no existe"
      elsif @level.discarded?
        @errors << "El nivel organizacional está eliminado"
      end
    end

    # VALIDACIÓN CRÍTICA: Valida la jerarquía correcta
    def validate_hierarchy
      return if @level.nil? # Ya validado en validate_params

      # Si es el primer nivel, NO debe tener padre
      if @level.first_level?
        if @params[:parent_id].present?
          @errors << "Los nodos del primer nivel no pueden tener padre"
        end
      else
        # Si NO es el primer nivel, DEBE tener padre
        if @params[:parent_id].blank?
          @errors << "Los nodos de este nivel deben tener un nodo padre"
          return
        end

        # Validar que el padre exista y esté activo
        @parent = OrganizationalNode.find_by(id: @params[:parent_id])
        if @parent.nil?
          @errors << "El nodo padre no existe"
          return
        elsif @parent.discarded?
          @errors << "El nodo padre está eliminado"
          return
        end

        # REGLA DE NEGOCIO: El padre debe ser del nivel inmediatamente anterior
        expected_parent_level_order = @level.level_order - 1
        parent_level_order = @parent.organizational_level.level_order

        if parent_level_order != expected_parent_level_order
          @errors << "El nodo padre debe pertenecer al nivel #{expected_parent_level_order}"
        end
      end
    end

    # Crea el nodo
    def create_node
      @node = OrganizationalNode.new(
        name: @params[:name],
        description: @params[:description],
        code: @params[:code],
        organizational_level_id: @params[:organizational_level_id],
        parent_id: @params[:parent_id]
      )

      unless @node.save
        @errors.concat(@node.errors.full_messages)
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
    rescue StandardError => e
      @errors << "Error al crear el nodo: #{e.message}"
    end
  end
end
