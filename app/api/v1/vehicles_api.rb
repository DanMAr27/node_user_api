# app/api/v1/vehicles_api.rb
module V1
  class VehiclesApi < Grape::API
    resource :vehicles do
      # GET /api/v1/vehicles
      # Lista vehículos con filtros
      desc "Lista vehículos con filtros opcionales" do
        success Entities::VehicleEntity
      end
      params do
        optional :plate, type: String, desc: "Filtrar por matrícula (parcial)"
        optional :brand, type: String, desc: "Filtrar por marca (parcial)"
        optional :model, type: String, desc: "Filtrar por modelo (parcial)"
        optional :year, type: Integer, desc: "Filtrar por año"
        optional :vin, type: String, desc: "Filtrar por VIN"
        optional :node_id, type: Integer, desc: "Filtrar por nodo específico"
        optional :branch_node_id, type: Integer, desc: "Filtrar por rama (nodo + descendientes)"
        optional :level_id, type: Integer, desc: "Filtrar por nivel organizacional"
        optional :search, type: String, desc: "Búsqueda general"
        optional :user_id, type: Integer, desc: "Filtrar por visibilidad de usuario"
        optional :order_by, type: String, desc: "Campo de ordenamiento",
                 values: [ "plate", "brand", "year", "created_at", "node" ], default: "created_at"
        optional :order_direction, type: String, desc: "Dirección",
                 values: [ "asc", "desc" ], default: "desc"
        optional :include_location, type: Boolean, desc: "Incluir ubicación organizacional"
        optional :include_node, type: Boolean, desc: "Incluir nodo completo"
      end
      get do
        query = VehiclesQuery.new

        filters = {
          plate: params[:plate],
          brand: params[:brand],
          model: params[:model],
          year: params[:year],
          vin: params[:vin],
          node_id: params[:node_id],
          level_id: params[:level_id],
          search: params[:search],
          order_by: params[:order_by],
          order_direction: params[:order_direction]
        }

        # Filtro por rama si se especifica
        if params[:branch_node_id].present?
          filters[:branch_node] = OrganizationalNode.kept.find(params[:branch_node_id])
        end

        # Filtro por visibilidad de usuario
        if params[:user_id].present?
          filters[:user] = User.kept.find(params[:user_id])
        end

        vehicles = query.call(filters)

        present vehicles,
                with: Entities::VehicleEntity,
                include_location: params[:include_location],
                include_node: params[:include_node]
      end

      # GET /api/v1/vehicles/statistics
      # Obtiene estadísticas de vehículos
      desc "Obtiene estadísticas de vehículos" do
        success code: 200
      end
      params do
        optional :node_id, type: Integer, desc: "Estadísticas de un nodo específico"
        optional :branch_node_id, type: Integer, desc: "Estadísticas de una rama"
        optional :user_id, type: Integer, desc: "Estadísticas de visibilidad de usuario"
      end
      get :statistics do
        query = VehiclesQuery.new

        filters = {}

        if params[:node_id].present?
          filters[:node_id] = params[:node_id]
        elsif params[:branch_node_id].present?
          filters[:branch_node] = OrganizationalNode.kept.find(params[:branch_node_id])
        elsif params[:user_id].present?
          filters[:user] = User.kept.find(params[:user_id])
        end

        query.call(filters)
        stats = query.statistics

        success_response(stats)
      end

      # GET /api/v1/vehicles/:id
      # Obtiene un vehículo específico
      desc "Obtiene un vehículo por ID" do
        success Entities::VehicleEntity
        failure [ [ 404, "No encontrado" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del vehículo"
        optional :include_location, type: Boolean, desc: "Incluir ubicación"
        optional :include_node, type: Boolean, desc: "Incluir nodo completo"
      end
      get ":id" do
        vehicle = Vehicle.kept.find(params[:id])

        present vehicle,
                with: Entities::VehicleEntity,
                include_location: params[:include_location],
                include_node: params[:include_node]
      end

      # POST /api/v1/vehicles
      # Crea un nuevo vehículo y lo asigna a un nodo
      desc "Crea un nuevo vehículo" do
        success Entities::VehicleEntity
        failure [ [ 422, "Error de validación" ] ]
      end
      params do
        requires :plate, type: String, desc: "Matrícula del vehículo"
        requires :organizational_node_id, type: Integer, desc: "ID del nodo organizacional"
        optional :brand, type: String, desc: "Marca"
        optional :model, type: String, desc: "Modelo"
        optional :year, type: Integer, desc: "Año"
        optional :vin, type: String, desc: "VIN"
        optional :description, type: String, desc: "Descripción"
      end
      post do
        service = Vehicles::Assigner.new(
          plate: params[:plate],
          organizational_node_id: params[:organizational_node_id],
          brand: params[:brand],
          model: params[:model],
          year: params[:year],
          vin: params[:vin],
          description: params[:description]
        )

        if service.call
          present service.vehicle,
                  with: Entities::VehicleEntity,
                  include_location: true
        else
          error_response_from_service(service)
        end
      end

      # PUT /api/v1/vehicles/:id
      # Actualiza un vehículo
      desc "Actualiza un vehículo" do
        success Entities::VehicleEntity
        failure [ [ 404, "No encontrado" ], [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del vehículo"
        optional :plate, type: String, desc: "Matrícula"
        optional :brand, type: String, desc: "Marca"
        optional :model, type: String, desc: "Modelo"
        optional :year, type: Integer, desc: "Año"
        optional :vin, type: String, desc: "VIN"
        optional :description, type: String, desc: "Descripción"
      end
      put ":id" do
        vehicle = Vehicle.kept.find(params[:id])

        update_params = {}
        update_params[:plate] = params[:plate] if params[:plate].present?
        update_params[:brand] = params[:brand] if params[:brand].present?
        update_params[:model] = params[:model] if params[:model].present?
        update_params[:year] = params[:year] if params[:year].present?
        update_params[:vin] = params[:vin] if params[:vin].present?
        update_params[:description] = params[:description] if params.key?(:description)

        if vehicle.update(update_params)
          present vehicle, with: Entities::VehicleEntity
        else
          error!({ error: "Error al actualizar", details: vehicle.errors.full_messages }, 422)
        end
      end

      # POST /api/v1/vehicles/:id/relocate
      # Reubica un vehículo a otro nodo
      desc "Reubica un vehículo a otro nodo organizacional" do
        success Entities::VehicleEntity
        failure [ [ 404, "No encontrado" ], [ 422, "Error de validación" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del vehículo"
        requires :new_node_id, type: Integer, desc: "ID del nuevo nodo"
        optional :reason, type: String, desc: "Razón de la reubicación"
      end
      post ":id/relocate" do
        vehicle = Vehicle.kept.find(params[:id])

        service = Vehicles::Relocator.new(
          vehicle,
          params[:new_node_id],
          reason: params[:reason]
        )

        if service.call
          response_data = {
            vehicle: service.vehicle,
            relocation_info: service.relocation_info
          }
          present service.vehicle,
                  with: Entities::VehicleEntity,
                  include_location: true
        else
          error_response_from_service(service)
        end
      end

      # DELETE /api/v1/vehicles/:id
      # Elimina un vehículo
      desc "Elimina un vehículo" do
        success code: 200, message: "Vehículo eliminado"
        failure [ [ 404, "No encontrado" ] ]
      end
      params do
        requires :id, type: Integer, desc: "ID del vehículo"
      end
      delete ":id" do
        vehicle = Vehicle.kept.find(params[:id])

        if vehicle.discard
          success_response(nil, "Vehículo eliminado exitosamente")
        else
          error!({ error: "Error al eliminar el vehículo" }, 422)
        end
      end
    end
  end
end
