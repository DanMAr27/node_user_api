# app/models/user.rb
class User < ApplicationRecord
  include SoftDeletable

  # Asociaciones
  has_many :node_user_accesses, dependent: :destroy
  has_many :accessible_nodes, through: :node_user_accesses,
                               source: :organizational_node
  has_many :granted_accesses, class_name: "NodeUserAccess",
                               foreign_key: :granted_by_id,
                               dependent: :nullify

  # Validaciones
  validates :email, presence: true,
                    length: { maximum: 100 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :phone, length: { maximum: 20 }

  # Normalización
  before_validation :normalize_email

  # Scopes
  scope :by_email, ->(email) { where("email ILIKE ?", "%#{email}%") }
  scope :by_name, ->(name) {
    where("first_name ILIKE ? OR last_name ILIKE ?", "%#{name}%", "%#{name}%")
  }
  scope :with_access, -> { joins(:node_user_accesses).distinct }
  scope :without_access, -> {
    left_joins(:node_user_accesses)
      .where(node_user_accesses: { id: nil })
  }

  # Métodos de instancia

  def full_name
    "#{first_name} #{last_name}"
  end

  def to_s
    full_name
  end

  # Verificar si tiene acceso a un nodo específico
  def has_access_to?(node)
    return false if node.nil?

    # Verificar si tiene acceso directo o a algún ancestro
    accessible_node_ids = accessible_nodes.pluck(:id)
    node_and_ancestors_ids = node.self_and_ancestors.pluck(:id)

    (accessible_node_ids & node_and_ancestors_ids).any?
  end

  # Verificar si puede ver un vehículo
  def can_view_vehicle?(vehicle)
    return false if vehicle.nil?
    has_access_to?(vehicle.organizational_node)
  end

  # Obtener todos los vehículos visibles
  def visible_vehicles
    Vehicle.visible_for_user(self)
  end

  # Obtener todos los nodos visibles (incluyendo descendientes de nodos accesibles)
  def visible_nodes
    return OrganizationalNode.none if accessible_nodes.empty?

    node_ids = accessible_nodes.flat_map do |node|
      node.self_and_descendants.pluck(:id)
    end.uniq

    OrganizationalNode.where(id: node_ids)
  end

  # Contar vehículos visibles
  def visible_vehicles_count
    visible_vehicles.count
  end

  # Contar nodos accesibles (directos)
  def accessible_nodes_count
    accessible_nodes.count
  end

  # Verificar si tiene algún acceso asignado
  def has_any_access?
    accessible_nodes.exists?
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end
end
