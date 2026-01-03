# app/api/entities/error_entity.rb
module Entities
  class ErrorEntity < Grape::Entity
    # Mensaje de error principal
    expose :error, documentation: { type: "String", desc: "Mensaje de error" }

    # Detalles adicionales (opcional)
    expose :details, documentation: { type: "Array", desc: "Detalles adicionales del error" }, if: ->(instance, options) {
      instance.is_a?(Hash) && instance[:details].present?
    }

    # Código de error (opcional)
    expose :code, documentation: { type: "String", desc: "Código de error" }, if: ->(instance, options) {
      instance.is_a?(Hash) && instance[:code].present?
    }

    # Timestamp del error
    expose :timestamp do |instance|
      Time.current.iso8601
    end
  end
end
