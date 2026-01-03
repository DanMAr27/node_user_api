# app/queries/organizational_nodes_query.rb
class OrganizationalNodesQuery
  # Inicializa la query con una relación base de OrganizationalNode
  # Por defecto usa todos los nodos activos (kept)
  def initialize(relation = OrganizationalNode.all)
    @relation = relation
  end

  # Método principal que aplica todos los filtros y retorna la relación
  def call(filters = {})
    @relation = apply_filters(filters)
    @relation
  end

  # Buscar por nivel organizacional específico
  # Ejemplo: query.by_level(1) -> todos los nodos del nivel 1
  def by_level(level_id)
    return @relation if level_id.blank?
    @relation = @relation.where(organizational_level_id: level_id)
    self
  end

  # Buscar solo nodos raíz (sin padre)
  # Útil para construir árboles desde arriba
  def roots_only
    @relation = @relation.where(ancestry: nil)
    self
  end

  # Buscar solo nodos hoja (sin hijos)
  # Útil para listar nodos finales donde se asignan vehículos
  def leaves_only
    @relation = @relation.where.not(
      id: OrganizationalNode.select(:parent_id).distinct
    )
    self
  end

  # Buscar por profundidad específica
  # Ejemplo: at_depth(2) -> nodos a 2 niveles del root
  def at_depth(depth)
    return @relation if depth.blank?
    @relation = @relation.where(ancestry_depth: depth)
    self
  end

  # Buscar nodos que sean descendientes de un nodo específico
  # Incluye el nodo mismo si include_self es true
  def descendants_of(node, include_self: false)
    return @relation if node.blank?

    if include_self
      node_ids = node.self_and_descendants.pluck(:id)
    else
      node_ids = node.descendants.pluck(:id)
    end

    @relation = @relation.where(id: node_ids)
    self
  end

  # Buscar nodos que sean ancestros de un nodo específico
  def ancestors_of(node, include_self: false)
    return @relation if node.blank?

    if include_self
      node_ids = node.self_and_ancestors.pluck(:id)
    else
      node_ids = node.ancestors.pluck(:id)
    end

    @relation = @relation.where(id: node_ids)
    self
  end

  # Buscar por nombre (búsqueda parcial, case insensitive)
  # Ejemplo: by_name("Madrid") -> encuentra "Madrid Centro", "madrid", etc.
  def by_name(name)
    return @relation if name.blank?
    @relation = @relation.where("name ILIKE ?", "%#{sanitize(name)}%")
    self
  end

  # Buscar por código exacto
  def by_code(code)
    return @relation if code.blank?
    @relation = @relation.where(code: code)
    self
  end

  # Buscar nodos que tienen vehículos asignados
  # Si minimum es especificado, solo nodos con al menos esa cantidad
  def with_vehicles(minimum: 1)
    @relation = @relation
      .joins(:vehicles)
      .group("organizational_nodes.id")
      .having("COUNT(vehicles.id) >= ?", minimum)
    self
  end

  # Buscar nodos sin vehículos asignados
  def without_vehicles
    @relation = @relation
      .left_joins(:vehicles)
      .where(vehicles: { id: nil })
    self
  end

  # Buscar nodos con usuarios asignados
  def with_users
    @relation = @relation
      .joins(:node_user_accesses)
      .distinct
    self
  end

  # Buscar nodos sin usuarios asignados
  def without_users
    @relation = @relation
      .left_joins(:node_user_accesses)
      .where(node_user_accesses: { id: nil })
    self
  end

  # Ordenar por diferentes criterios
  def ordered_by(field, direction = :asc)
    direction = direction.to_sym

    case field.to_s
    when "name"
      @relation = @relation.order(name: direction)
    when "level"
      @relation = @relation
        .joins(:organizational_level)
        .order("organizational_levels.level_order #{direction}")
    when "depth"
      @relation = @relation.order(ancestry_depth: direction)
    when "created_at"
      @relation = @relation.order(created_at: direction)
    when "vehicles_count"
      # Ordenar por cantidad de vehículos (requiere join)
      @relation = @relation
        .left_joins(:vehicles)
        .group("organizational_nodes.id")
        .order("COUNT(vehicles.id) #{direction}")
    else
      @relation = @relation.order(name: :asc)
    end

    self
  end

  # Construir árbol jerárquico completo
  # Retorna un hash anidado con la estructura del árbol
  # Formato: { node => { child_node => {}, another_child => {} } }
  def as_tree
    @relation.arrange
  end

  # Obtener estadísticas de los nodos en la query
  def statistics
    {
      total_nodes: @relation.count,
      root_nodes: @relation.where(ancestry: nil).count,
      leaf_nodes: @relation.where.not(
        id: OrganizationalNode.select(:parent_id).distinct
      ).count,
      total_vehicles: Vehicle.where(
        organizational_node_id: @relation.select(:id)
      ).count,
      nodes_with_vehicles: @relation.joins(:vehicles).distinct.count,
      nodes_with_users: @relation.joins(:node_user_accesses).distinct.count,
      average_depth: @relation.average(:ancestry_depth).to_f.round(2)
    }
  end

  # Buscar nodos accesibles por un usuario específico
  # Retorna los nodos que el usuario puede ver
  def accessible_by_user(user)
    return @relation.none if user.blank?

    accessible_node_ids = user.accessible_nodes.pluck(:id)
    return @relation.none if accessible_node_ids.empty?

    # Expandir a todos los descendientes de los nodos accesibles
    all_accessible_ids = OrganizationalNode
      .where(id: accessible_node_ids)
      .flat_map { |node| node.self_and_descendants.pluck(:id) }
      .uniq

    @relation = @relation.where(id: all_accessible_ids)
    self
  end

  private

  # Aplica múltiples filtros de una vez desde un hash
  # Ejemplo: apply_filters({ level_id: 1, name: "Madrid", roots_only: true })
  def apply_filters(filters)
    result = @relation

    result = by_level(filters[:level_id]) if filters[:level_id].present?
    result = by_name(filters[:name]) if filters[:name].present?
    result = by_code(filters[:code]) if filters[:code].present?
    result = at_depth(filters[:depth]) if filters[:depth].present?
    result = roots_only if filters[:roots_only]
    result = leaves_only if filters[:leaves_only]
    result = with_vehicles if filters[:with_vehicles]
    result = without_vehicles if filters[:without_vehicles]
    result = with_users if filters[:with_users]
    result = without_users if filters[:without_users]
    result = descendants_of(filters[:parent_node], include_self: filters[:include_parent]) if filters[:parent_node].present?
    result = accessible_by_user(filters[:user]) if filters[:user].present?
    result = ordered_by(filters[:order_by] || "name", filters[:order_direction] || :asc)

    @relation
  end

  # Sanitiza input del usuario para evitar SQL injection
  def sanitize(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end
end
