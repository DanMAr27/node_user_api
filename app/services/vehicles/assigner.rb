# app/services/vehicles/assigner.rb
module Vehicles
  class Assigner
    # Crea un nuevo vehículo y lo asigna a un nodo organizacional
    # @param params [Hash] Atributos del vehículo
    #   - :plate [String] Matrícula (obligatorio)
    #   - :organizational_node_id [Integer] Nodo destino (obligatorio)
    #   - :brand [String] Marca (opcional)
    #   - :model [String] Modelo (opcional)
    #   - :year [Integer] Año (opcional)
    #   - :vin [String] VIN (opcional)
    #   - :description [String] Descripción (opcional)
    def initialize(params)
      @params = params
      @vehicle = nil
      @errors = []
    end

    def call
      validate_params
      return false if @errors.any?

      validate_node
      return false if @errors.any?

      create_and_assign_vehicle
      @errors.empty?
    end

    attr_reader :vehicle, :errors

    def success?
      @errors.empty? && @vehicle.present? && @vehicle.persisted?
    end

    private

    # Validaciones básicas de parámetros
    def validate_params
      if @params[:plate].blank?
        @errors << "La matrícula es obligatoria"
      end

      if @params[:organizational_node_id].blank?
        @errors << "El nodo organizacional es obligatorio"
      end

      # Validar año si se proporciona
      if @params[:year].present?
        unless @params[:year].is_a?(Integer)
          @errors << "El año debe ser un número entero"
        end

        if @params[:year] < 1900
          @errors << "El año debe ser mayor a 1900"
        end

        if @params[:year] > Date.current.year + 1
          @errors << "El año no puede ser mayor a #{Date.current.year + 1}"
        end
      end

      # Validar que la matrícula no exista
      if @params[:plate].present?
        normalized_plate = @params[:plate].upcase.strip
        if Vehicle.exists?(plate: normalized_plate)
          @errors << "La matrícula ya está registrada"
        end
      end

      # Validar que el VIN no exista si se proporciona
      if @params[:vin].present?
        normalized_vin = @params[:vin].upcase.strip
        if Vehicle.exists?(vin: normalized_vin)
          @errors << "El VIN ya está registrado"
        end
      end
    end

    # Valida que el nodo exista y esté activo
    def validate_node
      @node = OrganizationalNode.find_by(id: @params[:organizational_node_id])

      if @node.nil?
        @errors << "El nodo organizacional no existe"
      elsif @node.discarded?
        @errors << "El nodo organizacional está eliminado"
      end
    end

    # Crea el vehículo y lo asigna al nodo
    def create_and_assign_vehicle
      @vehicle = Vehicle.new(
        plate: @params[:plate],
        brand: @params[:brand],
        model: @params[:model],
        year: @params[:year],
        vin: @params[:vin],
        description: @params[:description],
        organizational_node_id: @params[:organizational_node_id]
      )

      unless @vehicle.save
        @errors.concat(@vehicle.errors.full_messages)
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
    rescue StandardError => e
      @errors << "Error al crear el vehículo: #{e.message}"
    end
  end
end
