# app/queries/vehicles_query.rb
class VehiclesQuery
  # Inicializa con relación base de vehículos activos
  def initialize(relation = Vehicle.all)
    @relation = relation
  end

  # Método principal que aplica filtros y retorna la relación
  def call(filters = {})
    @relation = apply_filters(filters)
    @relation
  end

  # Filtrar por matrícula (búsqueda parcial)
  # Ejemplo: by_plate("ABC") -> encuentra "ABC123", "123ABC", etc.
  def by_plate(plate)
    return @relation if plate.blank?
    @relation = @relation.where("plate ILIKE ?", "%#{sanitize(plate)}%")
    self
  end

  # Filtrar por VIN exacto
  def by_vin(vin)
    return @relation if vin.blank?
    @relation = @relation.where(vin: vin.upcase.strip)
    self
  end

  # Filtrar por marca (búsqueda parcial)
  def by_brand(brand)
    return @relation if brand.blank?
    @relation = @relation.where("brand ILIKE ?", "%#{sanitize(brand)}%")
    self
  end

  # Filtrar por modelo (búsqueda parcial)
  def by_model(model)
    return @relation if model.blank?
    @relation = @relation.where("model ILIKE ?", "%#{sanitize(model)}%")
    self
  end

  # Filtrar por año o rango de años
  # Ejemplos:
  #   by_year(2020) -> año exacto
  #   by_year(2020..2023) -> rango
  #   by_year([2020, 2021, 2023]) -> años específicos
  def by_year(year)
    return @relation if year.blank?

    case year
    when Range
      @relation = @relation.where(year: year)
    when Array
      @relation = @relation.where(year: year)
    else
      @relation = @relation.where(year: year)
    end

    self
  end

  # Filtrar por nodo organizacional específico (sin herencia)
  # Solo vehículos asignados directamente a ese nodo
  def in_node(node_id)
    return @relation if node_id.blank?
    @relation = @relation.where(organizational_node_id: node_id)
    self
  end

  # Filtrar por nodo y todos sus descendientes (con herencia)
  # CLAVE: Implementa la visibilidad jerárquica
  # Ejemplo: Si filtras por "España", verás vehículos de Madrid, Barcelona, etc.
  def in_branch(node)
    return @relation if node.blank?

    # Obtener el nodo y todos sus descendientes
    node_ids = node.self_and_descendants.pluck(:id)
    @relation = @relation.where(organizational_node_id: node_ids)
    self
  end

  # Filtrar por múltiples ramas (múltiples nodos)
  # Útil cuando un usuario tiene acceso a varios nodos
  def in_branches(nodes)
    return @relation if nodes.blank?

    node_ids = nodes.flat_map do |node|
      node.self_and_descendants.pluck(:id)
    end.uniq

    @relation = @relation.where(organizational_node_id: node_ids)
    self
  end

  # Filtrar por nivel organizacional
  # Ejemplo: by_level(3) -> vehículos en el nivel "CECO"
  def by_level(level_id)
    return @relation if level_id.blank?

    @relation = @relation
      .joins(:organizational_node)
      .where(organizational_nodes: { organizational_level_id: level_id })
    self
  end

  # MÉTODO CRÍTICO: Filtrar vehículos visibles para un usuario
  # Implementa la lógica completa de visibilidad basada en herencia jerárquica
  def visible_for_user(user)
    return @relation.none if user.blank?

    # Obtener nodos a los que el usuario tiene acceso
    accessible_nodes = user.accessible_nodes.to_a
    return @relation.none if accessible_nodes.empty?

    # Obtener vehículos en todas las ramas de esos nodos
    @relation = in_branches(accessible_nodes)
    self
  end

  # Buscar en múltiples campos a la vez (búsqueda general)
  # Busca en: plate, brand, model, description
  def search(term)
    return @relation if term.blank?

    sanitized_term = sanitize(term)
    @relation = @relation.where(
      "plate ILIKE :term OR brand ILIKE :term OR model ILIKE :term OR description ILIKE :term",
      term: "%#{sanitized_term}%"
    )
    self
  end

  # Filtrar por rango de fechas de creación
  def created_between(start_date, end_date)
    return @relation if start_date.blank? || end_date.blank?

    @relation = @relation.where(created_at: start_date..end_date)
    self
  end

  # Ordenar por diferentes criterios
  def ordered_by(field, direction = :asc)
    direction = direction.to_sym

    case field.to_s
    when "plate"
      @relation = @relation.order(plate: direction)
    when "brand"
      @relation = @relation.order(brand: direction, model: direction)
    when "year"
      @relation = @relation.order(year: direction)
    when "created_at"
      @relation = @relation.order(created_at: direction)
    when "node"
      # Ordenar por nombre del nodo organizacional
      @relation = @relation
        .joins(:organizational_node)
        .order("organizational_nodes.name #{direction}")
    when "level"
      # Ordenar por nivel organizacional
      @relation = @relation
        .joins(organizational_node: :organizational_level)
        .order("organizational_levels.level_order #{direction}")
    else
      @relation = @relation.order(created_at: :desc)
    end

    self
  end

  # Obtener estadísticas de los vehículos en la query
  def statistics
    {
      total_vehicles: @relation.count,
      by_brand: @relation.group(:brand).count,
      by_year: @relation.group(:year).order("year DESC").count,
      by_level: @relation
        .joins(organizational_node: :organizational_level)
        .group("organizational_levels.name")
        .count,
      oldest_year: @relation.minimum(:year),
      newest_year: @relation.maximum(:year),
      most_recent: @relation.maximum(:created_at),
      nodes_count: @relation.select(:organizational_node_id).distinct.count
    }
  end

  # Agrupar vehículos por nodo organizacional
  # Retorna hash: { node_id => [vehicles] }
  def group_by_node
    @relation
      .includes(:organizational_node)
      .group_by(&:organizational_node_id)
  end

  # Agrupar vehículos por nivel organizacional
  # Retorna hash: { level_name => [vehicles] }
  def group_by_level
    @relation
      .includes(organizational_node: :organizational_level)
      .group_by { |v| v.organizational_node.organizational_level.name }
  end

  # Contar vehículos por nodo
  # Retorna hash: { node_id => count }
  def count_by_node
    @relation.group(:organizational_node_id).count
  end

  # Contar vehículos por marca
  def count_by_brand
    @relation.group(:brand).count
  end

  # Obtener vehículos duplicados por matrícula
  # Útil para detectar inconsistencias
  def duplicated_plates
    plates = @relation
      .group(:plate)
      .having("COUNT(*) > 1")
      .pluck(:plate)

    @relation.where(plate: plates).order(:plate)
  end

  # Vehículos sin información completa
  # (sin marca, modelo o año)
  def incomplete_data
    @relation.where(
      "brand IS NULL OR model IS NULL OR year IS NULL"
    )
    self
  end

  # Vehículos creados recientemente (últimos N días)
  def recent(days = 7)
    @relation = @relation.where("created_at >= ?", days.days.ago)
    self
  end

  private

  # Aplica múltiples filtros desde un hash
  def apply_filters(filters)
    result = @relation

    result = by_plate(filters[:plate]) if filters[:plate].present?
    result = by_vin(filters[:vin]) if filters[:vin].present?
    result = by_brand(filters[:brand]) if filters[:brand].present?
    result = by_model(filters[:model]) if filters[:model].present?
    result = by_year(filters[:year]) if filters[:year].present?
    result = in_node(filters[:node_id]) if filters[:node_id].present?
    result = in_branch(filters[:branch_node]) if filters[:branch_node].present?
    result = by_level(filters[:level_id]) if filters[:level_id].present?
    result = visible_for_user(filters[:user]) if filters[:user].present?
    result = search(filters[:search]) if filters[:search].present?
    result = created_between(filters[:start_date], filters[:end_date]) if filters[:start_date] && filters[:end_date]
    result = recent(filters[:recent_days]) if filters[:recent_days].present?
    result = incomplete_data if filters[:incomplete_data]
    result = ordered_by(filters[:order_by] || "created_at", filters[:order_direction] || :desc)

    @relation
  end

  # Sanitiza input para evitar SQL injection
  def sanitize(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end
end
