# app/models/node_user_access.rb
class NodeUserAccess < ApplicationRecord
  include SoftDeletable

  # Asociaciones
  belongs_to :user
  belongs_to :organizational_node
  belongs_to :granted_by, class_name: "User", optional: true

  # Validaciones
  validates :user_id, presence: true,
                      uniqueness: {
                        scope: :organizational_node_id,
                        conditions: -> { kept },
                        message: "ya tiene acceso a este nodo"
                      }
  validates :organizational_node_id, presence: true

  # Validación personalizada: no permitir acceso redundante
  validate :avoid_redundant_access, on: :create

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_node, ->(node) { where(organizational_node: node) }
  scope :granted_by_user, ->(user) { where(granted_by: user) }
  scope :recent, -> { order(granted_at: :desc) }
  scope :oldest, -> { order(granted_at: :asc) }

  # Callbacks
  after_create :set_granted_at

  # Métodos de instancia

  def to_s
    "#{user.full_name} -> #{organizational_node.name}"
  end

  # Verificar si el acceso fue otorgado recientemente (últimas 24 horas)
  def recently_granted?
    granted_at && granted_at > 24.hours.ago
  end

  # Obtener días desde que se otorgó el acceso
  def days_since_granted
    return 0 unless granted_at
    ((Time.current - granted_at) / 1.day).to_i
  end

  # Verificar si el acceso cubre vehículos
  def covers_vehicles?
    organizational_node.total_vehicles_count > 0
  end

  # Obtener cantidad de vehículos cubiertos por este acceso
  def covered_vehicles_count
    organizational_node.total_vehicles_count
  end

  # Obtener cantidad de nodos descendientes cubiertos
  def covered_nodes_count
    organizational_node.descendants_count
  end

  private

  def set_granted_at
    update_column(:granted_at, Time.current) if granted_at.nil?
  end

  # Validar que no se cree un acceso redundante
  # (el usuario ya tiene acceso al nodo o a un ancestro)
  def avoid_redundant_access
    return if user.nil? || organizational_node.nil?

    # Verificar si el usuario ya tiene acceso a un ancestro de este nodo
    user_node_ids = user.accessible_nodes.pluck(:id)
    node_ancestor_ids = organizational_node.ancestor_ids

    if (user_node_ids & node_ancestor_ids).any?
      errors.add(:base, "El usuario ya tiene acceso a un nodo superior que incluye este nodo")
    end

    # Verificar si el usuario tiene accesos a descendientes de este nodo
    node_descendant_ids = organizational_node.descendant_ids
    redundant_descendants = user_node_ids & node_descendant_ids

    if redundant_descendants.any?
      errors.add(:base, "Este acceso haría redundantes otros accesos existentes a nodos descendientes")
    end
  end
end
