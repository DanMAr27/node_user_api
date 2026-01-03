# app/api/v1/organizational_levels_api.rb
module V1
  class OrganizationalLevelsApi < Grape::API
    resource :organizational_levels do
      # GET /api/v1/organizational_levels
      # Lista todos los niveles organizacionales
      desc "Lista todos los niveles organizacionales" do
        success Entities::OrganizationalLevelEntity
        failure [ [ 401, "No autorizado" ], [ 500, "Error interno" ] ]
      end
      params do
        optional :include_nodes, type: Boolean, desc: "Incluir nodos en la respuesta"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
      end
      get do
        levels = OrganizationalLevel.kept.ordered

        present levels,
                with: Entities::OrganizationalLevelEntity,
                include_nodes: params[:include_nodes],
                include_counts: params[:include_counts]
      end

      # GET /api/v1/organizational_levels/:id
      # Obtiene un nivel específico
      desc "Obtiene un nivel organizacional por ID" do
        success Entities::OrganizationalLevelEntity
        failure [ [ 404, "No encontrado" ], [ 500, "Error interno" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nivel organizacional"
        optional :include_nodes, type: Boolean, desc: "Incluir nodos en la respuesta"
        optional :include_counts, type: Boolean, desc: "Incluir contadores"
      end
      get ":id" do
        level = OrganizationalLevel.kept.find(params[:id])

        present level,
                with: Entities::OrganizationalLevelEntity,
                include_nodes: params[:include_nodes],
                include_counts: params[:include_counts]
      end

      # POST /api/v1/organizational_levels
      # Crea un nuevo nivel organizacional
      desc "Crea un nuevo nivel organizacional" do
        success Entities::OrganizationalLevelEntity
        failure [ [ 400, "Parámetros inválidos" ], [ 422, "Error de validación" ] ]
      end
      params do
        requires :name, type: String, desc: "Nombre del nivel"
        requires :level_order, type: Integer, desc: "Orden del nivel en la jerarquía"
        optional :description, type: String, desc: "Descripción del nivel"
      end
      post do
        service = OrganizationalLevels::Creator.new(
          name: params[:name],
          level_order: params[:level_order],
          description: params[:description]
        )

        if service.call
          present service.level, with: Entities::OrganizationalLevelEntity
        else
          error_response_from_service(service)
        end
      end

      # PUT /api/v1/organizational_levels/:id
      # Actualiza un nivel organizacional
      desc "Actualiza un nivel organizacional" do
        success Entities::OrganizationalLevelEntity
        failure [ [ 404, "No encontrado" ], [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nivel organizacional"
        optional :name, type: String, desc: "Nombre del nivel"
        optional :level_order, type: Integer, desc: "Orden del nivel"
        optional :description, type: String, desc: "Descripción del nivel"
      end
      put ":id" do
        level = OrganizationalLevel.kept.find(params[:id])

        service = OrganizationalLevels::Updater.new(
          level,
          name: params[:name],
          level_order: params[:level_order],
          description: params[:description]
        )

        if service.call
          present service.level, with: Entities::OrganizationalLevelEntity
        else
          error_response_from_service(service)
        end
      end

      # DELETE /api/v1/organizational_levels/:id
      # Elimina (soft delete) un nivel organizacional
      desc "Elimina un nivel organizacional" do
        success code: 200, message: "Nivel eliminado exitosamente"
        failure [ [ 404, "No encontrado" ], [ 422, "No se puede eliminar" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del nivel organizacional"
      end
      delete ":id" do
        level = OrganizationalLevel.kept.find(params[:id])

        service = OrganizationalLevels::Destroyer.new(level)

        if service.call
          success_response(nil, "Nivel organizacional eliminado exitosamente")
        else
          error_response_from_service(service)
        end
      end
    end
  end
end
