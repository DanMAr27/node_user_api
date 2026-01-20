# app/models/organizational_node.rb
class OrganizationalNode < ApplicationRecord
  include SoftDeletable
  include HierarchyQueryable

  # Ancestry para jerarquía
  has_ancestry cache_depth: true, orphan_strategy: :restrict

  # Asociaciones
  belongs_to :organizational_level
  has_many :vehicles, dependent: :restrict_with_error
  has_many :node_user_accesses, dependent: :destroy
  has_many :users, through: :node_user_accesses

  # Validaciones
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, length: { maximum: 50 },
                   uniqueness: { conditions: -> { kept }, allow_blank: true }
  validates :organizational_level_id, presence: true

  # Validación personalizada: el parent debe ser del nivel inmediatamente superior
  validate :parent_must_be_from_previous_level, if: -> { parent_id.present? && (new_record? || will_save_change_to_parent_id?) }

  # Scopes
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :by_code, ->(code) { where(code: code) }
  scope :by_level, ->(level_id) { where(organizational_level_id: level_id) }
  scope :roots_of_level, ->(level_id) { by_level(level_id).where(ancestry: nil) }

  # Métodos de instancia

  def to_s
    name
  end

  # Obtener cantidad de vehículos asignados directamente
  def vehicles_count
    self[:vehicles_count] || 0
  end

  # Obtener cantidad de vehículos en toda la rama (incluyendo descendientes)
  def total_vehicles_count
    Vehicle.in_branch(self).count
  end

  # Obtener cantidad de nodos hijos
  def children_count
    children.count
  end

  # Obtener cantidad total de nodos descendientes
  def descendants_count
    descendants.count
  end

  # Verificar si puede ser eliminado
  def can_be_deleted?
    vehicles.empty? && children.empty?
  end

  # Obtener el código completo (con códigos de ancestros)
  def full_code(separator: "-")
    return code if root_node?

    codes = self_and_ancestors.map(&:code).compact
    codes.join(separator)
  end

  # Verificar si pertenece a un nivel específico
  def belongs_to_level?(level)
    organizational_level_id == level.id
  end

  private

  def parent_must_be_from_previous_level
    return if parent.nil? # Los nodos raíz no tienen parent

    expected_parent_level_order = organizational_level.level_order - 1

    if expected_parent_level_order < 1
      errors.add(:parent_id, "no puede existir para el nivel más alto")
      return
    end

    parent_level_order = parent.organizational_level.level_order

    unless parent_level_order == expected_parent_level_order
      errors.add(:parent_id, "debe pertenecer al nivel #{expected_parent_level_order}")
    end
  end
end
