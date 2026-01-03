# app/models/organizational_level.rb
class OrganizationalLevel < ApplicationRecord
  include SoftDeletable

  # Asociaciones
  has_many :organizational_nodes, dependent: :restrict_with_error

  # Validaciones
  validates :name, presence: true, length: { maximum: 100 }
  validates :level_order, presence: true,
                          numericality: { only_integer: true, greater_than: 0 },
                          uniqueness: { conditions: -> { kept } }

  # Scopes
  scope :ordered, -> { order(:level_order) }
  scope :by_order, ->(order) { where(level_order: order) }

  # Métodos de instancia

  def to_s
    name
  end

  # Verificar si tiene nodos asociados
  def has_nodes?
    organizational_nodes.exists?
  end

  # Obtener el siguiente nivel
  def next_level
    self.class.kept.where("level_order > ?", level_order).order(:level_order).first
  end

  # Obtener el nivel anterior
  def previous_level
    self.class.kept.where("level_order < ?", level_order).order(level_order: :desc).first
  end

  # Verificar si es el primer nivel
  def first_level?
    level_order == 1
  end

  # Verificar si es el último nivel
  def last_level?
    self.class.kept.maximum(:level_order) == level_order
  end

  # Métodos de clase

  def self.first_level
    kept.order(:level_order).first
  end

  def self.last_level
    kept.order(:level_order).last
  end

  def self.find_by_order(order)
    kept.find_by(level_order: order)
  end
end
