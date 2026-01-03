# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  include SoftDeletable
  include VisibilityScopes

  # Asociaciones
  belongs_to :organizational_node

  # Delegaciones para acceso rápido
  delegate :organizational_level, to: :organizational_node
  delegate :full_path, to: :organizational_node, prefix: true

  # Validaciones
  validates :plate, presence: true,
                    length: { maximum: 20 },
                    uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :vin, length: { maximum: 17 },
                  uniqueness: { conditions: -> { kept }, allow_blank: true }
  validates :brand, length: { maximum: 50 }
  validates :model, length: { maximum: 50 }
  validates :year, numericality: { only_integer: true,
                                   greater_than: 1900,
                                   less_than_or_equal_to: -> { Date.current.year + 1 } },
                   allow_nil: true
  validates :organizational_node_id, presence: true

  # Normalización
  before_validation :normalize_plate
  before_validation :normalize_vin

  # Scopes
  scope :by_plate, ->(plate) { where("plate ILIKE ?", "%#{plate}%") }
  scope :by_brand, ->(brand) { where("brand ILIKE ?", "%#{brand}%") }
  scope :by_model, ->(model) { where("model ILIKE ?", "%#{model}%") }
  scope :by_year, ->(year) { where(year: year) }
  scope :by_vin, ->(vin) { where(vin: vin) }
  scope :recent, -> { order(created_at: :desc) }

  # Métodos de instancia

  def to_s
    "#{plate} - #{full_name}"
  end

  def full_name
    parts = [ brand, model, year ].compact
    parts.join(" ")
  end

  # Obtener ubicación organizacional completa
  def location_path
    organizational_node_full_path
  end

  # Verificar si puede ser reubicado
  def can_be_relocated?
    true # En un POC simple, siempre puede reubicarse
  end

  # Obtener ancestros organizacionales
  def organizational_ancestors
    organizational_node.ancestors
  end

  private

  def normalize_plate
    self.plate = plate&.upcase&.strip
  end

  def normalize_vin
    self.vin = vin&.upcase&.strip if vin.present?
  end
end
