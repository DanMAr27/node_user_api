# app/services/user_access/access_manager.rb
module UserAccess
  class AccessManager
    # Gestiona la asignación y revocación de accesos de usuarios a nodos
    # Este servicio es CRÍTICO para la seguridad y visibilidad del sistema
    #
    # @param user [User] Usuario al que se le gestiona el acceso
    def initialize(user)
      @user = user
      @errors = []
      @granted_accesses = []
      @revoked_accesses = []
    end

    # Otorga acceso a un nodo
    # @param node_id [Integer] ID del nodo
    # @param granted_by [User] Usuario que otorga el acceso (para auditoría)
    # @return [Boolean]
    def grant_access(node_id, granted_by: nil)
      @errors = []

      validate_user
      return false if @errors.any?

      validate_node(node_id)
      return false if @errors.any?

      check_existing_access(node_id)
      return false if @errors.any?

      create_access(node_id, granted_by)
      @errors.empty?
    end

    # Revoca acceso a un nodo
    # @param node_id [Integer] ID del nodo
    # @return [Boolean]
    def revoke_access(node_id)
      @errors = []

      validate_user
      return false if @errors.any?

      find_and_revoke_access(node_id)
      @errors.empty?
    end

    # Otorga acceso a múltiples nodos en batch
    # @param node_ids [Array<Integer>] IDs de los nodos
    # @param granted_by [User] Usuario que otorga el acceso
    # @return [Boolean]
    def grant_multiple_accesses(node_ids, granted_by: nil)
      @errors = []
      @granted_accesses = []

      validate_user
      return false if @errors.any?

      if node_ids.blank? || !node_ids.is_a?(Array)
        @errors << "Debe proporcionar un array de IDs de nodos"
        return false
      end

      ActiveRecord::Base.transaction do
        node_ids.each do |node_id|
          result = grant_access(node_id, granted_by: granted_by)

          unless result
            # Si alguno falla, hacemos rollback de todos
            raise ActiveRecord::Rollback
          end
        end
      end

      @errors.empty?
    rescue StandardError => e
      @errors << "Error al otorgar accesos múltiples: #{e.message}"
      false
    end

    # Revoca acceso a múltiples nodos en batch
    # @param node_ids [Array<Integer>] IDs de los nodos
    # @return [Boolean]
    def revoke_multiple_accesses(node_ids)
      @errors = []
      @revoked_accesses = []

      validate_user
      return false if @errors.any?

      if node_ids.blank? || !node_ids.is_a?(Array)
        @errors << "Debe proporcionar un array de IDs de nodos"
        return false
      end

      ActiveRecord::Base.transaction do
        node_ids.each do |node_id|
          result = revoke_access(node_id)

          unless result
            raise ActiveRecord::Rollback
          end
        end
      end

      @errors.empty?
    rescue StandardError => e
      @errors << "Error al revocar accesos múltiples: #{e.message}"
      false
    end

    # Reemplaza TODOS los accesos del usuario con una nueva lista
    # CUIDADO: Esta operación elimina todos los accesos existentes
    # @param node_ids [Array<Integer>] Nueva lista de IDs de nodos
    # @param granted_by [User] Usuario que realiza el cambio
    # @return [Boolean]
    def replace_all_accesses(node_ids, granted_by: nil)
      @errors = []
      @granted_accesses = []
      @revoked_accesses = []

      validate_user
      return false if @errors.any?

      ActiveRecord::Base.transaction do
        # 1. Revocar todos los accesos existentes
        current_accesses = @user.node_user_accesses
        current_accesses.each do |access|
          access.discard
          @revoked_accesses << access
        end

        # 2. Crear los nuevos accesos
        node_ids.each do |node_id|
          result = grant_access(node_id, granted_by: granted_by)

          unless result
            raise ActiveRecord::Rollback
          end
        end
      end

      @errors.empty?
    rescue StandardError => e
      @errors << "Error al reemplazar accesos: #{e.message}"
      false
    end

    # Retorna información sobre los accesos otorgados en esta operación
    def granted_accesses_info
      @granted_accesses.map do |access|
        {
          access_id: access.id,
          node_id: access.organizational_node_id,
          node_name: access.organizational_node.name,
          granted_at: access.granted_at
        }
      end
    end

    # Retorna información sobre los accesos revocados en esta operación
    def revoked_accesses_info
      @revoked_accesses.map do |access|
        {
          access_id: access.id,
          node_id: access.organizational_node_id,
          node_name: access.organizational_node.name,
          revoked_at: Time.current
        }
      end
    end

    attr_reader :errors, :granted_accesses, :revoked_accesses

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

    def validate_node(node_id)
      @node = OrganizationalNode.find_by(id: node_id)

      if @node.nil?
        @errors << "Nodo organizacional no encontrado"
      elsif @node.discarded?
        @errors << "Nodo organizacional eliminado"
      end
    end

    # VALIDACIÓN CRÍTICA: Verifica si ya existe un acceso
    # También verifica accesos redundantes (si el usuario ya tiene acceso a un ancestro)
    def check_existing_access(node_id)
      # Verificar si ya tiene acceso directo a este nodo
      if @user.node_user_accesses.exists?(organizational_node_id: node_id)
        @errors << "El usuario ya tiene acceso a este nodo"
        return
      end

      # VALIDACIÓN ANTI-REDUNDANCIA:
      # Verificar si el usuario ya tiene acceso a un nodo ancestro
      # Si tiene acceso a "España", no necesita acceso a "Madrid"
      user_node_ids = @user.accessible_nodes.pluck(:id)
      node_ancestor_ids = @node.ancestor_ids

      if (user_node_ids & node_ancestor_ids).any?
        ancestor_names = OrganizationalNode.where(id: user_node_ids & node_ancestor_ids).pluck(:name)
        @errors << "El usuario ya tiene acceso a un nodo superior (#{ancestor_names.join(', ')}) que incluye este nodo"
        return
      end

      # Verificar si el usuario tiene accesos a descendientes
      # Si otorgamos acceso a "España", los accesos a "Madrid" y "Barcelona" serían redundantes
      node_descendant_ids = @node.descendant_ids
      redundant_descendants = user_node_ids & node_descendant_ids

      if redundant_descendants.any?
        descendant_names = OrganizationalNode.where(id: redundant_descendants).pluck(:name)
        @errors << "Este acceso haría redundantes los accesos existentes a: #{descendant_names.join(', ')}"
      end
    end

    def create_access(node_id, granted_by)
      access = NodeUserAccess.new(
        user: @user,
        organizational_node_id: node_id,
        granted_by: granted_by,
        granted_at: Time.current
      )

      if access.save
        @granted_accesses << access
      else
        @errors.concat(access.errors.full_messages)
      end
    rescue StandardError => e
      @errors << "Error al crear el acceso: #{e.message}"
    end

    def find_and_revoke_access(node_id)
      access = @user.node_user_accesses.find_by(organizational_node_id: node_id)

      if access.nil?
        @errors << "El usuario no tiene acceso a este nodo"
        return
      end

      if access.discard
        @revoked_accesses << access
      else
        @errors << "Error al revocar el acceso"
      end
    rescue StandardError => e
      @errors << "Error al revocar el acceso: #{e.message}"
    end
  end
end
