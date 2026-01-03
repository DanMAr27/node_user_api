# app/services/organizational_nodes/updater.rb
module OrganizationalNodes
  class Updater
    # Actualiza un nodo organizacional
    # Puede actualizar atributos básicos Y mover el nodo a otro padre
    # @param node [OrganizationalNode] Nodo a actualizar
    # @param params [Hash] Nuevos atributos
    def initialize(node, params)
      @node = node
      @params = params
      @errors = []
      @parent_changed = false
    end

    def call
      validate_node
      return false if @errors.any?

      validate_params
      return false if @errors.any?

      # Si se cambia el padre, validar la nueva jerarquía
      if parent_will_change?
        @parent_changed = true
        validate_new_hierarchy
        return false if @errors.any?
      end

      update_node
      @errors.empty?
    end

    attr_reader :node, :errors

    def success?
      @errors.empty?
    end

    # Indica si el nodo fue movido a otro padre
    def parent_moved?
      @parent_changed
    end

    private

    def validate_node
      if @node.nil?
        @errors << "Nodo no encontrado"
      elsif @node.discarded?
        @errors << "No se puede actualizar un nodo eliminado"
      end
    end

    def validate_params
      if @params[:name].present? && @params[:name].blank?
        @errors << "El nombre no puede estar vacío"
      end

      # Validar código único si se proporciona
      if @params[:code].present? && @params[:code] != @node.code
        if OrganizationalNode.where.not(id: @node.id).exists?(code: @params[:code])
          @errors << "El código ya está en uso"
        end
      end
    end

    # Verifica si el parent_id cambiará
    def parent_will_change?
      @params.key?(:parent_id) && @params[:parent_id] != @node.parent_id
    end

    # VALIDACIÓN CRÍTICA: Valida que el movimiento del nodo sea válido
    def validate_new_hierarchy
      new_parent_id = @params[:parent_id]

      # Si el nuevo padre es nil, debe ser un nodo del primer nivel
      if new_parent_id.nil?
        unless @node.organizational_level.first_level?
          @errors << "Solo los nodos del primer nivel pueden no tener padre"
        end
        return
      end

      # Validar que el nuevo padre exista
      @new_parent = OrganizationalNode.find_by(id: new_parent_id)
      if @new_parent.nil?
        @errors << "El nuevo nodo padre no existe"
        return
      elsif @new_parent.discarded?
        @errors << "El nuevo nodo padre está eliminado"
        return
      end

      # REGLA: No se puede mover un nodo para ser hijo de sí mismo
      if @new_parent.id == @node.id
        @errors << "Un nodo no puede ser padre de sí mismo"
        return
      end

      # REGLA CRÍTICA: No se puede mover un nodo para ser hijo de uno de sus descendientes
      # Esto crearía un ciclo en el árbol
      if @new_parent.descendant_of?(@node)
        @errors << "No se puede mover un nodo a uno de sus descendientes (crearía un ciclo)"
        return
      end

      # REGLA: El nuevo padre debe ser del nivel inmediatamente anterior
      expected_parent_level_order = @node.organizational_level.level_order - 1
      new_parent_level_order = @new_parent.organizational_level.level_order

      if new_parent_level_order != expected_parent_level_order
        @errors << "El nuevo padre debe pertenecer al nivel #{expected_parent_level_order}"
      end
    end

    # Actualiza el nodo
    def update_node
      update_params = {}

      update_params[:name] = @params[:name] if @params[:name].present?
      update_params[:description] = @params[:description] if @params.key?(:description)
      update_params[:code] = @params[:code] if @params.key?(:code)

      # IMPORTANTE: Cambiar el parent_id mueve todo el subárbol
      # Ancestry maneja automáticamente la actualización de todos los descendientes
      update_params[:parent_id] = @params[:parent_id] if @params.key?(:parent_id)

      unless @node.update(update_params)
        @errors.concat(@node.errors.full_messages)
      end
    rescue StandardError => e
      @errors << "Error al actualizar el nodo: #{e.message}"
    end
  end
end
