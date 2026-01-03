# app/api/v1/user_accesses_api.rb
module V1
  class UserAccessesApi < Grape::API
    # Endpoints para gestión de usuarios
    resource :users do
      # GET /api/v1/users
      # Lista usuarios
      desc "Lista usuarios" do
        success Entities::UserEntity
      end
      params do
        optional :email, type: String, desc: "Filtrar por email"
        optional :name, type: String, desc: "Filtrar por nombre"
        optional :with_access, type: Boolean, desc: "Solo usuarios con accesos"
        optional :include_access_info, type: Boolean, desc: "Incluir info de accesos"
      end
      get do
        users = User.kept
        users = users.by_email(params[:email]) if params[:email].present?
        users = users.by_name(params[:name]) if params[:name].present?
        users = users.with_access if params[:with_access]

        present users,
                with: Entities::UserEntity,
                include_access_info: params[:include_access_info]
      end

      # GET /api/v1/users/:id
      # Obtiene un usuario
      desc "Obtiene un usuario por ID" do
        success Entities::UserEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        optional :include_accessible_nodes, type: Boolean, desc: "Incluir nodos accesibles"
      end
      get ":id" do
        user = User.kept.find(params[:id])

        present user,
                with: Entities::UserEntity,
                include_access_info: true,
                include_accessible_nodes: params[:include_accessible_nodes]
      end

      # GET /api/v1/users/:id/access_tree
      # Obtiene el árbol completo con indicadores de acceso del usuario
      # Este endpoint es para la vista de edición de accesos del usuario
      desc "Obtiene árbol completo con accesos del usuario marcados" do
        success code: 200
        detail "Retorna el árbol organizacional completo con flags indicando qué nodos tiene acceso el usuario"
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        optional :max_depth, type: Integer, desc: "Profundidad máxima del árbol"
      end
      get ":id/access_tree" do
        user = User.kept.find(params[:id])

        # Obtener nodos con acceso directo (los que están en NodeUserAccess)
        direct_access_nodes = user.accessible_nodes
        direct_access_node_ids = direct_access_nodes.pluck(:id)

        # Obtener todos los nodos visibles por herencia
        visible_node_ids = user.visible_nodes.pluck(:id)

        # Construir árbol completo
        service = OrganizationalNodes::TreeBuilder.new(nil, {
          include_counts: true,
          include_vehicles: false,
          max_depth: params[:max_depth]
        })

        tree = service.call

        if service.success?
          # Agregar información de acceso a cada nodo del árbol
          annotated_tree = annotate_tree_with_access(tree, direct_access_node_ids, visible_node_ids)

          success_response({
            tree: annotated_tree,
            user: {
              id: user.id,
              name: user.full_name,
              email: user.email
            },
            summary: {
              total_nodes: OrganizationalNode.count,
              direct_access_count: direct_access_node_ids.count,
              inherited_access_count: visible_node_ids.count - direct_access_node_ids.count,
              total_visible_count: visible_node_ids.count,
              no_access_count: OrganizationalNode.count - visible_node_ids.count
            },
            legend: {
              direct: "Nodo con acceso directo asignado (checkbox seleccionado)",
              inherited: "Nodo visible por herencia (descendiente de un nodo con acceso)",
              none: "Sin acceso (puede ser asignado)"
            }
          })
        else
          error_response_from_service(service)
        end
      end

      # Helper para anotar el árbol con información de acceso
      helpers do
        # Anota recursivamente el árbol con información de acceso
        def annotate_tree_with_access(tree, direct_ids, visible_ids)
          return [] if tree.blank?

          tree = [ tree ] unless tree.is_a?(Array)

          tree.map do |node|
            annotated_node = node.dup

            node_id = node[:id]
            has_direct = direct_ids.include?(node_id)
            is_visible = visible_ids.include?(node_id)

            # Determinar el tipo de acceso
            access_type = if has_direct
              "direct"
            elsif is_visible
              "inherited"
            else
              "none"
            end

            # Agregar información de acceso
            annotated_node[:access] = {
              has_direct_access: has_direct,
              is_visible_by_inheritance: is_visible && !has_direct,
              is_visible: is_visible,
              type: access_type,
              # Para el frontend: indica si el checkbox debe estar marcado
              checked: has_direct,
              # Para el frontend: indica si debe mostrarse como heredado (ej: color diferente)
              inherited: is_visible && !has_direct,
              # Para el frontend: indica si está disponible para asignar
              assignable: !has_direct
            }

            # Anotar hijos recursivamente
            if node[:children].present? && node[:children].is_a?(Array)
              annotated_node[:children] = annotate_tree_with_access(
                node[:children],
                direct_ids,
                visible_ids
              )
            end

            annotated_node
          end
        end
      end

      # GET /api/v1/users/:id/accesses
      # Lista los accesos de un usuario
      desc "Lista los accesos de un usuario" do
        success Entities::NodeUserAccessEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        optional :include_node, type: Boolean, desc: "Incluir información del nodo"
        optional :include_coverage, type: Boolean, desc: "Incluir métricas de cobertura"
      end
      get ":id/accesses" do
        user = User.kept.find(params[:id])
        accesses = user.node_user_accesses.kept

        present accesses,
                with: Entities::NodeUserAccessEntity,
                include_node: params[:include_node],
                include_coverage: params[:include_coverage]
      end

      # GET /api/v1/users/:id/visible_nodes
      # Obtiene todos los nodos visibles para un usuario
      desc "Obtiene nodos visibles para un usuario (con herencia)" do
        success Entities::OrganizationalNodeEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
      end
      get ":id/visible_nodes" do
        user = User.kept.find(params[:id])
        visible_nodes = user.visible_nodes

        present visible_nodes,
                with: Entities::OrganizationalNodeEntity,
                include_counts: params[:include_counts]
      end

      # GET /api/v1/users/:id/visible_vehicles
      # Obtiene todos los vehículos visibles para un usuario
      desc "Obtiene vehículos visibles para un usuario" do
        success Entities::VehicleEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        optional :include_location, type: Boolean, desc: "Incluir ubicación"
      end
      get ":id/visible_vehicles" do
        user = User.kept.find(params[:id])
        visible_vehicles = user.visible_vehicles

        present visible_vehicles,
                with: Entities::VehicleEntity,
                include_location: params[:include_location]
      end

      # GET /api/v1/users/:id/visibility_scope
      # Calcula el alcance de visibilidad de un usuario
      desc "Calcula el alcance de visibilidad de un usuario" do
        success code: 200
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
      end
      get ":id/visibility_scope" do
        user = User.kept.find(params[:id])
        calculator = UserAccess::VisibilityCalculator.new(user)

        scope = calculator.visibility_scope
        success_response(scope)
      end

      # POST /api/v1/users/:id/grant_access
      # Otorga acceso a un nodo
      desc "Otorga acceso a un nodo organizacional" do
        success Entities::NodeUserAccessEntity
        failure [ [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        requires :node_id, type: Integer, desc: "ID del nodo organizacional"
        optional :granted_by_id, type: Integer, desc: "ID del usuario que otorga el acceso"
      end
      post ":id/grant_access" do
        user = User.kept.find(params[:id])
        granted_by = params[:granted_by_id].present? ? User.kept.find(params[:granted_by_id]) : nil

        manager = UserAccess::AccessManager.new(user)

        if manager.grant_access(params[:node_id], granted_by: granted_by)
          access = manager.granted_accesses.first
          present access,
                  with: Entities::NodeUserAccessEntity,
                  include_node: true
        else
          error_response_from_service(manager)
        end
      end

      # POST /api/v1/users/:id/grant_multiple_accesses
      # Otorga acceso a múltiples nodos
      desc "Otorga acceso a múltiples nodos" do
        success Entities::NodeUserAccessEntity
        failure [ [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        requires :node_ids, type: Array[Integer], desc: "Array de IDs de nodos"
        optional :granted_by_id, type: Integer, desc: "ID del usuario que otorga"
      end
      post ":id/grant_multiple_accesses" do
        user = User.kept.find(params[:id])
        granted_by = params[:granted_by_id].present? ? User.kept.find(params[:granted_by_id]) : nil

        manager = UserAccess::AccessManager.new(user)

        if manager.grant_multiple_accesses(params[:node_ids], granted_by: granted_by)
          present manager.granted_accesses,
                  with: Entities::NodeUserAccessEntity,
                  include_node: true
        else
          error_response_from_service(manager)
        end
      end

      # DELETE /api/v1/users/:id/revoke_access
      # Revoca acceso a un nodo
      desc "Revoca acceso a un nodo" do
        success code: 200, message: "Acceso revocado"
        failure [ [ 422, "Error" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        requires :node_id, type: Integer, desc: "ID del nodo"
      end
      delete ":id/revoke_access" do
        user = User.kept.find(params[:id])

        manager = UserAccess::AccessManager.new(user)

        if manager.revoke_access(params[:node_id])
          success_response(nil, "Acceso revocado exitosamente")
        else
          error_response_from_service(manager)
        end
      end

      # PUT /api/v1/users/:id/replace_all_accesses
      # Reemplaza TODOS los accesos del usuario
      desc "Reemplaza todos los accesos del usuario" do
        success Entities::NodeUserAccessEntity
        failure [ [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del usuario"
        requires :node_ids, type: Array[Integer], desc: "Nueva lista de IDs de nodos"
        optional :granted_by_id, type: Integer, desc: "ID del usuario que realiza el cambio"
      end
      put ":id/replace_all_accesses" do
        user = User.kept.find(params[:id])
        granted_by = params[:granted_by_id].present? ? User.kept.find(params[:granted_by_id]) : nil

        manager = UserAccess::AccessManager.new(user)

        if manager.replace_all_accesses(params[:node_ids], granted_by: granted_by)
          response_data = {
            granted: manager.granted_accesses_info,
            revoked: manager.revoked_accesses_info
          }
          success_response(response_data, "Accesos actualizados exitosamente")
        else
          error_response_from_service(manager)
        end
      end
    end

    # Endpoints para análisis de accesos
    resource :accesses do
      # GET /api/v1/accesses
      # Lista todos los accesos con filtros
      desc "Lista accesos con filtros" do
        success Entities::NodeUserAccessEntity
      end
      params do
        optional :user_id, type: Integer, desc: "Filtrar por usuario"
        optional :node_id, type: Integer, desc: "Filtrar por nodo"
        optional :level_id, type: Integer, desc: "Filtrar por nivel"
        optional :recent_days, type: Integer, desc: "Accesos recientes (últimos N días)"
        optional :redundant, type: Boolean, desc: "Solo accesos redundantes"
        optional :include_user, type: Boolean, desc: "Incluir usuario"
        optional :include_node, type: Boolean, desc: "Incluir nodo"
      end
      get do
        query = UserAccessQuery.new

        filters = {
          user: params[:user_id].present? ? User.kept.find(params[:user_id]) : nil,
          node: params[:node_id].present? ? OrganizationalNode.kept.find(params[:node_id]) : nil,
          level_id: params[:level_id],
          recent_days: params[:recent_days],
          redundant: params[:redundant]
        }

        accesses = query.call(filters)

        present accesses,
                with: Entities::NodeUserAccessEntity,
                include_user: params[:include_user],
                include_node: params[:include_node]
      end

      # GET /api/v1/accesses/statistics
      # Estadísticas de accesos
      desc "Obtiene estadísticas de accesos" do
        success code: 200
      end
      get :statistics do
        query = UserAccessQuery.new
        stats = query.statistics

        success_response(stats)
      end

      # GET /api/v1/accesses/visibility_coverage
      # Análisis de cobertura de visibilidad
      desc "Análisis de cobertura de visibilidad por usuario" do
        success code: 200
      end
      get :visibility_coverage do
        query = UserAccessQuery.new
        coverage = query.visibility_coverage

        # Transformar hash con user objects a formato serializable
        coverage_data = coverage.transform_values do |info|
          {
            user_name: info[:user].full_name,
            user_email: info[:user].email,
            direct_nodes: info[:direct_nodes],
            visible_nodes: info[:visible_nodes],
            visible_vehicles: info[:visible_vehicles]
          }
        end

        success_response(coverage_data)
      end

      # GET /api/v1/accesses/matrix
      # Matriz de acceso (auditoría)
      desc "Obtiene matriz de acceso para auditoría" do
        success code: 200
      end
      get :matrix do
        query = UserAccessQuery.new
        matrix = query.access_matrix

        success_response(matrix)
      end
    end
  end
end
