# app/queries/user_access_query.rb
class UserAccessQuery
  # Inicializa con relación base de accesos activos
  def initialize(relation = NodeUserAccess.all)
    @relation = relation
  end

  # Método principal
  def call(filters = {})
    @relation = apply_filters(filters)
    @relation
  end

  # Filtrar accesos de un usuario específico
  def for_user(user)
    return @relation if user.blank?
    @relation = @relation.where(user: user)
    self
  end

  # Filtrar accesos a un nodo específico
  def for_node(node)
    return @relation if node.blank?
    @relation = @relation.where(organizational_node: node)
    self
  end

  # Filtrar accesos otorgados por un usuario específico
  def granted_by(user)
    return @relation if user.blank?
    @relation = @relation.where(granted_by: user)
    self
  end

  # Filtrar accesos otorgados en un rango de fechas
  def granted_between(start_date, end_date)
    return @relation if start_date.blank? || end_date.blank?
    @relation = @relation.where(granted_at: start_date..end_date)
    self
  end

  # Filtrar accesos recientes (últimos N días)
  def recent(days = 7)
    @relation = @relation.where("granted_at >= ?", days.days.ago)
    self
  end

  # Filtrar por nivel organizacional
  # Ejemplo: Accesos a nodos del nivel "Departamento"
  def by_level(level_id)
    return @relation if level_id.blank?

    @relation = @relation
      .joins(:organizational_node)
      .where(organizational_nodes: { organizational_level_id: level_id })
    self
  end

  # Accesos que cubren vehículos
  # Solo accesos donde el nodo (o sus descendientes) tienen vehículos
  def covering_vehicles
    node_ids_with_vehicles = Vehicle.select(:organizational_node_id).distinct

    @relation = @relation.where(
      organizational_node_id: OrganizationalNode
        .where(id: node_ids_with_vehicles)
        .or(
          OrganizationalNode.where(
            id: OrganizationalNode
              .where(id: node_ids_with_vehicles)
              .flat_map { |n| n.ancestor_ids }
          )
        )
        .select(:id)
    )
    self
  end

  # Accesos a nodos sin vehículos (potencialmente redundantes o inútiles)
  def without_vehicles
    node_ids_without_vehicles = OrganizationalNode
      .left_joins(:vehicles)
      .where(vehicles: { id: nil })
      .pluck(:id)

    @relation = @relation.where(organizational_node_id: node_ids_without_vehicles)
    self
  end

  # Ordenar por diferentes criterios
  def ordered_by(field, direction = :asc)
    direction = direction.to_sym

    case field.to_s
    when "granted_at"
      @relation = @relation.order(granted_at: direction)
    when "user"
      @relation = @relation
        .joins(:user)
        .order("users.first_name #{direction}, users.last_name #{direction}")
    when "node"
      @relation = @relation
        .joins(:organizational_node)
        .order("organizational_nodes.name #{direction}")
    when "level"
      @relation = @relation
        .joins(organizational_node: :organizational_level)
        .order("organizational_levels.level_order #{direction}")
    else
      @relation = @relation.order(granted_at: :desc)
    end

    self
  end

  # MÉTODO CRÍTICO: Detectar accesos redundantes
  # Un acceso es redundante si el usuario ya tiene acceso a un ancestro
  # Ejemplo: Si tiene acceso a "España", el acceso a "Madrid" es redundante
  def redundant_accesses
    # Obtener todos los accesos agrupados por usuario
    user_ids = @relation.select(:user_id).distinct.pluck(:user_id)
    redundant_ids = []

    user_ids.each do |user_id|
      user_accesses = @relation.where(user_id: user_id).includes(:organizational_node)

      user_accesses.each do |access|
        node = access.organizational_node
        ancestor_ids = node.ancestor_ids

        # Verificar si el usuario tiene acceso a algún ancestro
        has_ancestor_access = user_accesses.any? do |other_access|
          next if other_access.id == access.id
          ancestor_ids.include?(other_access.organizational_node_id)
        end

        redundant_ids << access.id if has_ancestor_access
      end
    end

    @relation = @relation.where(id: redundant_ids)
    self
  end

  # Detectar accesos que se solapan (mismos nodos o relacionados)
  def overlapping_for_user(user)
    return @relation.none if user.blank?

    user_accesses = @relation.where(user: user).includes(:organizational_node)
    overlapping_ids = []

    user_accesses.each do |access|
      node = access.organizational_node

      # Buscar otros accesos del mismo usuario que estén en la misma rama
      user_accesses.each do |other_access|
        next if access.id == other_access.id

        other_node = other_access.organizational_node

        # Son overlapping si uno es ancestro o descendiente del otro
        if node.ancestor_of?(other_node) || node.descendant_of?(other_node)
          overlapping_ids << access.id
          overlapping_ids << other_access.id
        end
      end
    end

    @relation = @relation.where(id: overlapping_ids.uniq)
    self
  end

  # Estadísticas de accesos
  def statistics
    {
      total_accesses: @relation.count,
      unique_users: @relation.select(:user_id).distinct.count,
      unique_nodes: @relation.select(:organizational_node_id).distinct.count,
      by_level: @relation
        .joins(organizational_node: :organizational_level)
        .group("organizational_levels.name")
        .count,
      recent_7_days: @relation.where("granted_at >= ?", 7.days.ago).count,
      recent_30_days: @relation.where("granted_at >= ?", 30.days.ago).count,
      with_vehicles: covering_vehicles.count,
      average_vehicles_per_access: calculate_average_vehicles_per_access
    }
  end

  # Usuarios con más accesos
  def top_users(limit = 10)
    @relation
      .group(:user_id)
      .order("COUNT(*) DESC")
      .limit(limit)
      .count
  end

  # Nodos más asignados
  def top_nodes(limit = 10)
    @relation
      .group(:organizational_node_id)
      .order("COUNT(*) DESC")
      .limit(limit)
      .count
  end

  # MÉTODO ANALÍTICO: Calcular cobertura de visibilidad
  # Retorna cuántos vehículos puede ver cada usuario
  def visibility_coverage
    result = {}

    user_ids = @relation.select(:user_id).distinct.pluck(:user_id)

    user_ids.each do |user_id|
      user = User.find(user_id)
      accessible_nodes = user.accessible_nodes

      # Expandir a todos los nodos visibles (con descendientes)
      visible_node_ids = accessible_nodes.flat_map do |node|
        node.self_and_descendants.pluck(:id)
      end.uniq

      # Contar vehículos en esos nodos
      vehicles_count = Vehicle.where(organizational_node_id: visible_node_ids).count

      result[user_id] = {
        user: user,
        direct_nodes: accessible_nodes.count,
        visible_nodes: visible_node_ids.count,
        visible_vehicles: vehicles_count
      }
    end

    result
  end

  # Matriz de acceso: qué usuarios tienen acceso a qué nodos
  # Útil para auditoría y visualización
  def access_matrix
    @relation
      .includes(:user, :organizational_node)
      .map do |access|
        {
          user_id: access.user_id,
          user_name: access.user.full_name,
          user_email: access.user.email,
          node_id: access.organizational_node_id,
          node_name: access.organizational_node.name,
          node_path: access.organizational_node.full_path,
          level_name: access.organizational_node.organizational_level.name,
          granted_at: access.granted_at,
          granted_by: access.granted_by&.full_name
        }
      end
  end

  private

  # Aplica filtros múltiples
  def apply_filters(filters)
    result = @relation

    result = for_user(filters[:user]) if filters[:user].present?
    result = for_node(filters[:node]) if filters[:node].present?
    result = granted_by(filters[:granted_by]) if filters[:granted_by].present?
    result = granted_between(filters[:start_date], filters[:end_date]) if filters[:start_date] && filters[:end_date]
    result = recent(filters[:recent_days]) if filters[:recent_days].present?
    result = by_level(filters[:level_id]) if filters[:level_id].present?
    result = covering_vehicles if filters[:covering_vehicles]
    result = without_vehicles if filters[:without_vehicles]
    result = redundant_accesses if filters[:redundant]
    result = ordered_by(filters[:order_by] || "granted_at", filters[:order_direction] || :desc)

    @relation
  end

  # Calcular promedio de vehículos por acceso
  def calculate_average_vehicles_per_access
    accesses_with_counts = @relation.includes(:organizational_node).map do |access|
      access.organizational_node.total_vehicles_count
    end

    return 0 if accesses_with_counts.empty?
    (accesses_with_counts.sum.to_f / accesses_with_counts.size).round(2)
  end
end
