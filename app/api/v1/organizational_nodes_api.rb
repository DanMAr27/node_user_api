# app/api/v1/organizational_nodes_api.rb
module V1
  class OrganizationalNodesApi < Grape::API
    resource :organizational_nodes do
      # GET /api/v1/organizational_nodes/for_select
      # Obtiene nodos en formato optimizado para select/dropdown
      desc "Obtiene nodos para select/dropdown" do
        success code: 200
        detail "Retorna lista de nodos con path completo, ideal para selects"
      end
      params do
        optional :level_id, type: Integer, desc: "Filtrar por nivel específico"
        optional :search, type: String, desc: "Buscar por nombre"
        optional :include_path, type: Boolean, desc: "Incluir ruta completa", default: true
        optional :user_id, type: Integer, desc: "Filtrar por nodos visibles para usuario"
        optional :grouped, type: Boolean, desc: "Agrupar por nivel", default: false
      end
      get :for_select do
        query = OrganizationalNodesQuery.new

        filters = {
          level_id: params[:level_id],
          name: params[:search],
          order_by: "name",
          order_direction: "asc"
        }

        # Filtrar por visibilidad de usuario si se especifica
        if params[:user_id].present?
          user = User.kept.find(params[:user_id])
          filters[:user] = user
        end

        nodes = query.call(filters).includes(:organizational_level)

        # Formatear según el tipo solicitado
        if params[:grouped]
          # Agrupado por nivel
          result = format_nodes_grouped(nodes, params[:include_path])
        else
          # Lista plana
          result = format_nodes_flat(nodes, params[:include_path])
        end

        success_response(result)
      end

      # Helpers para formatear nodos
      helpers do
        def format_nodes_flat(nodes, include_path)
          nodes.map do |node|
            {
              value: node.id,
              label: include_path ? node.full_path : node.name,
              name: node.name,
              code: node.code,
              level_id: node.organizational_level_id,
              level_name: node.organizational_level.name,
              level_order: node.organizational_level.level_order,
              depth: node.depth_level,
              full_path: node.full_path,
              is_leaf: node.leaf_node?,
              vehicle_count: node.vehicles_count
            }
          end
        end

        def format_nodes_grouped(nodes, include_path)
          grouped = nodes.group_by { |n| n.organizational_level }

          grouped.map do |level, level_nodes|
            {
              label: level.name,
              level_id: level.id,
              level_order: level.level_order,
              options: level_nodes.map do |node|
                {
                  value: node.id,
                  label: include_path ? node.full_path : node.name,
                  name: node.name,
                  code: node.code,
                  depth: node.depth_level,
                  full_path: node.full_path,
                  is_leaf: node.leaf_node?,
                  vehicle_count: node.vehicles_count
                }
              end
            }
          end.sort_by { |g| g[:level_order] }
        end
      end

      # GET /api/v1/organizational_nodes
      # Lista nodos con filtros opcionales
      desc "Lista nodos organizacionales con filtros" do
        success Entities::OrganizationalNodeEntity
      end
      params do
        optional :level_id, type: Integer, desc: "Filtrar por nivel organizacional"
        optional :parent_id, type: Integer, desc: "Filtrar por nodo padre"
        optional :name, type: String, desc: "Buscar por nombre (parcial)"
        optional :code, type: String, desc: "Buscar por código"
        optional :roots_only, type: Boolean, desc: "Solo nodos raíz"
        optional :leaves_only, type: Boolean, desc: "Solo nodos hoja"
        optional :with_vehicles, type: Boolean, desc: "Solo nodos con vehículos"
        optional :order_by, type: String, desc: "Campo de ordenamiento", values: [ "name", "level", "depth" ]
        optional :order_direction, type: String, desc: "Dirección", values: [ "asc", "desc" ], default: "asc"
        optional :include_level, type: Boolean, desc: "Incluir nivel organizacional"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
        optional :include_path, type: Boolean, desc: "Incluir ruta completa"
      end
      get do
        query = OrganizationalNodesQuery.new

        filters = {
          level_id: params[:level_id],
          name: params[:name],
          code: params[:code],
          roots_only: params[:roots_only],
          leaves_only: params[:leaves_only],
          with_vehicles: params[:with_vehicles],
          order_by: params[:order_by] || "name",
          order_direction: params[:order_direction]
        }

        # Filtro por parent_id si se especifica
        if params[:parent_id].present?
          parent_node = OrganizationalNode.kept.find(params[:parent_id])
          filters[:parent_node] = parent_node
          filters[:include_parent] = false
        end

        nodes = query.call(filters)

        present nodes,
                with: Entities::OrganizationalNodeEntity,
                include_level: params[:include_level],
                include_counts: params[:include_counts],
                include_path: params[:include_path]
      end

      # GET /api/v1/organizational_nodes/tree
      # Obtiene el árbol jerárquico completo
      desc "Obtiene el árbol jerárquico completo" do
        success Entities::OrganizationalTreeEntity
      end
      params do
        optional :root_node_id, type: Integer, desc: "ID del nodo raíz (opcional)"
        optional :max_depth, type: Integer, desc: "Profundidad máxima"
        optional :include_vehicles, type: Boolean, desc: "Incluir vehículos"
        optional :include_counts, type: Boolean, desc: "Incluir contadores", default: true
      end
      get :tree do
        root_node = params[:root_node_id].present? ?
                    OrganizationalNode.kept.find(params[:root_node_id]) :
                    nil

        service = OrganizationalNodes::TreeBuilder.new(root_node, {
          include_vehicles: params[:include_vehicles],
          include_counts: params[:include_counts],
          max_depth: params[:max_depth]
        })

        tree = service.call

        if service.success?
          present tree, with: Entities::OrganizationalTreeEntity
        else
          error_response_from_service(service)
        end
      end

      # GET /api/v1/organizational_nodes/:id
      # Obtiene un nodo específico
      desc "Obtiene un nodo organizacional por ID" do
        success Entities::OrganizationalNodeEntity
        failure [ [ 404, "No encontrado" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nodo"
        optional :include_level, type: Boolean, desc: "Incluir nivel"
        optional :include_parent, type: Boolean, desc: "Incluir padre"
        optional :include_children, type: Boolean, desc: "Incluir hijos"
        optional :include_vehicles, type: Boolean, desc: "Incluir vehículos"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
        optional :include_path, type: Boolean, desc: "Incluir ruta completa"
      end
      get ":id" do
        node = OrganizationalNode.kept.find(params[:id])

        # Preparar opciones de presentación
        presentation_opts = {
          include_level: params[:include_level],
          include_counts: params[:include_counts],
          include_path: params[:include_path]
        }

        # Para parent y children, no pasar las opciones recursivamente
        # Esto evita loops infinitos
        if params[:include_parent]
          presentation_opts[:include_parent] = true
        end

        if params[:include_children]
          presentation_opts[:include_children] = true
        end

        if params[:include_vehicles]
          presentation_opts[:include_vehicles] = true
        end

        present node, with: Entities::OrganizationalNodeEntity, **presentation_opts
      end

      # GET /api/v1/organizational_nodes/:id/descendants
      # Obtiene los descendientes de un nodo
      desc "Obtiene los descendientes de un nodo" do
        success Entities::OrganizationalNodeEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del nodo"
        optional :include_self, type: Boolean, desc: "Incluir el nodo mismo"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
      end
      get ":id/descendants" do
        node = OrganizationalNode.kept.find(params[:id])

        descendants = params[:include_self] ?
                      node.self_and_descendants :
                      node.descendants

        present descendants,
                with: Entities::OrganizationalNodeEntity,
                include_counts: params[:include_counts]
      end

      # GET /api/v1/organizational_nodes/:id/ancestors
      # Obtiene los ancestros de un nodo
      desc "Obtiene los ancestros de un nodo" do
        success Entities::OrganizationalNodeEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del nodo"
        optional :include_self, type: Boolean, desc: "Incluir el nodo mismo"
      end
      get ":id/ancestors" do
        node = OrganizationalNode.kept.find(params[:id])

        ancestors = params[:include_self] ?
                    node.self_and_ancestors :
                    node.ancestors

        present ancestors, with: Entities::OrganizationalNodeEntity
      end

      # POST /api/v1/organizational_nodes
      # Crea un nuevo nodo
      desc "Crea un nuevo nodo organizacional" do
        success Entities::OrganizationalNodeEntity
        failure [ [ 422, "Error de validación" ] ]
      end
      params do
        requires :name, type: String, desc: "Nombre del nodo"
        requires :organizational_level_id, type: Integer, desc: "ID del nivel"
        optional :parent_id, type: Integer, desc: "ID del nodo padre"
        optional :code, type: String, desc: "Código único"
        optional :description, type: String, desc: "Descripción"
      end
      post do
        service = OrganizationalNodes::Creator.new(
          name: params[:name],
          organizational_level_id: params[:organizational_level_id],
          parent_id: params[:parent_id],
          code: params[:code],
          description: params[:description]
        )

        if service.call
          present service.node, with: Entities::OrganizationalNodeEntity
        else
          error_response_from_service(service)
        end
      end

      # PUT /api/v1/organizational_nodes/:id
      # Actualiza un nodo (incluye mover a otro padre)
      desc "Actualiza un nodo organizacional" do
        success Entities::OrganizationalNodeEntity
        failure [ [ 404, "No encontrado" ], [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nodo"
        optional :name, type: String, desc: "Nombre del nodo"
        optional :parent_id, type: Integer, desc: "ID del nuevo padre (para mover el nodo)"
        optional :code, type: String, desc: "Código único"
        optional :description, type: String, desc: "Descripción"
      end
      put ":id" do
        node = OrganizationalNode.kept.find(params[:id])

        service = OrganizationalNodes::Updater.new(
          node,
          name: params[:name],
          parent_id: params[:parent_id],
          code: params[:code],
          description: params[:description]
        )

        if service.call
          response_data = {
            node: service.node,
            parent_moved: service.parent_moved?
          }
          present service.node, with: Entities::OrganizationalNodeEntity
        else
          error_response_from_service(service)
        end
      end

      # DELETE /api/v1/organizational_nodes/:id
      # Elimina un nodo
      desc "Elimina un nodo organizacional" do
        success code: 200, message: "Nodo eliminado"
        failure [ [ 404, "No encontrado" ], [ 422, "No se puede eliminar" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nodo"
        optional :strategy, type: String, desc: "Estrategia de eliminación",
                 values: [ "restrict", "cascade" ], default: "restrict"
      end
      delete ":id" do
        node = OrganizationalNode.kept.find(params[:id])

        service = OrganizationalNodes::Destroyer.new(
          node,
          strategy: params[:strategy].to_sym
        )

        if service.call
          message = "Nodo eliminado exitosamente (#{service.deleted_count} nodo(s) afectado(s))"
          success_response({ deleted_count: service.deleted_count }, message)
        else
          error_response_from_service(service)
        end
      end
    end
  end
end
