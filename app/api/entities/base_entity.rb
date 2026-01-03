# app/api/entities/base_entity.rb
module Entities
  class BaseEntity < Grape::Entity
    # Formato de fechas consistente en toda la API
    format_with(:iso_timestamp) { |dt| dt&.iso8601 }

    # Helper para exponer timestamps
    def self.expose_timestamps
      expose :created_at, format_with: :iso_timestamp
      expose :updated_at, format_with: :iso_timestamp
    end

    # Helper para exponer soft delete
    def self.expose_soft_delete
      expose :discarded_at, format_with: :iso_timestamp
      expose :active do |instance|
        !instance.discarded?
      end
    end

    # Helper para exponer IDs de forma consistente
    def self.expose_id
      expose :id, documentation: { type: "Integer", desc: "ID único del registro" }
    end
  end
end
