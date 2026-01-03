# app/api/v1/base.rb
module V1
  class Base < Grape::API
    version "v1", using: :path
    prefix :api
    format :json


    # Manejo global de errores
    rescue_from :all do |e|
      case e
      when Grape::Exceptions::ValidationErrors
        error_response = {
          error: "Errores de validación",
          details: e.errors.transform_keys(&:to_s)
        }
        error!(error_response, 400)

      when ActiveRecord::RecordNotFound
        error_response = {
          error: "Recurso no encontrado"
        }
        error!(error_response, 404)

      when ActiveRecord::RecordInvalid
        error_response = {
          error: "Datos inválidos",
          details: e.record.errors.full_messages
        }
        error!(error_response, 422)

      else
        # Log del error en producción
        Rails.logger.error("API Error: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        error_response = {
          error: "Error interno del servidor",
          message: Rails.env.production? ? "Ha ocurrido un error" : e.message
        }
        error!(error_response, 500)
      end
    end

    # Helpers comunes
    helpers do
      # Helper para respuestas de éxito
      def success_response(data, message = nil, status = 200)
        response = { success: true }
        response[:message] = message if message
        response[:data] = data if data
        status status
        response
      end

      # Helper para respuestas de error desde servicios
      def error_response_from_service(service, status = 422)
        error!({
          error: "Error al procesar la solicitud",
          details: service.errors
        }, status)
      end

      # Helper para parsear booleanos
      def parse_boolean(value)
        return nil if value.nil?
        [ "true", "1", "yes" ].include?(value.to_s.downcase)
      end

      # Helper para aplicar opciones de presentación
      def presentation_options
        options = {}

        # Parsear opciones desde query params
        params.each do |key, value|
          if key.to_s.start_with?("include_")
            options[key.to_sym] = parse_boolean(value)
          end
        end

        options
      end
    end

    # Montar las APIs de cada recurso
    mount V1::OrganizationalLevelsApi
    mount V1::OrganizationalNodesApi
    mount V1::VehiclesApi
    mount V1::UserAccessesApi

    # Configuración mínima de Swagger
    add_swagger_documentation(
      api_version: "v1",
      mount_path: "/swagger_doc", # endpoint JSON de Swagger
      hide_documentation_path: false,
      info: {
        title: "My Grape API V1",
        description: "Documentación básica de la API"
      },
        base_path: "/",
        host: Rails.env.production? ? "telemetry-api-guxp.onrender.com" : "localhost:3000",
        schemes: Rails.env.production? ? [ "https" ] : [ "http" ]
    )
  end
end
