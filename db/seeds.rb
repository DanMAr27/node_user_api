# db/seeds.rb
# Seeds para el Sistema de Estructura Organizacional Jerárquica

puts "🌱 Iniciando seeds..."
puts "=" * 80

# ============================================================================
# LIMPIEZA DE DATOS
# ============================================================================
puts "\n🗑️  Limpiando datos existentes..."

# Orden importante: eliminar primero las dependencias
NodeUserAccess.delete_all
Vehicle.delete_all
OrganizationalNode.delete_all
OrganizationalLevel.delete_all
User.delete_all

# Resetear secuencias de IDs (PostgreSQL)
if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.reset_pk_sequence!(table)
  end
end

puts "   ✓ Datos eliminados correctamente"

# ============================================================================
# CREAR NIVELES ORGANIZACIONALES
# ============================================================================
puts "\n📊 Creando niveles organizacionales..."

levels_data = [
  { name: 'País', description: 'Nivel geográfico nacional', level_order: 1 },
  { name: 'Región', description: 'Divisiones regionales del país', level_order: 2 },
  { name: 'Ciudad', description: 'Ciudades dentro de las regiones', level_order: 3 },
  { name: 'Departamento', description: 'Departamentos operativos', level_order: 4 },
  { name: 'CECO', description: 'Centros de costos', level_order: 5 }
]

levels = {}
levels_data.each do |data|
  level = OrganizationalLevel.create!(data)
  levels[level.name] = level
  puts "   ✓ Nivel: #{level.name} (orden: #{level.level_order})"
end

# ============================================================================
# CREAR ESTRUCTURA ORGANIZACIONAL
# ============================================================================
puts "\n🏢 Creando estructura organizacional..."

# Nivel 1: Países
puts "\n   Nivel 1 - Países:"
espana = OrganizationalNode.create!(
  name: 'España',
  code: 'ES',
  description: 'Operaciones en España',
  organizational_level: levels['País']
)
puts "      ✓ #{espana.name}"

francia = OrganizationalNode.create!(
  name: 'Francia',
  code: 'FR',
  description: 'Operaciones en Francia',
  organizational_level: levels['País']
)
puts "      ✓ #{francia.name}"

# Nivel 2: Regiones de España
puts "\n   Nivel 2 - Regiones (España):"
comunidad_madrid = OrganizationalNode.create!(
  name: 'Comunidad de Madrid',
  code: 'MAD',
  description: 'Región de Madrid',
  organizational_level: levels['Región'],
  parent: espana
)
puts "      ✓ #{comunidad_madrid.name}"

cataluna = OrganizationalNode.create!(
  name: 'Cataluña',
  code: 'CAT',
  description: 'Región de Cataluña',
  organizational_level: levels['Región'],
  parent: espana
)
puts "      ✓ #{cataluna.name}"

andalucia = OrganizationalNode.create!(
  name: 'Andalucía',
  code: 'AND',
  description: 'Región de Andalucía',
  organizational_level: levels['Región'],
  parent: espana
)
puts "      ✓ #{andalucia.name}"

# Nivel 2: Regiones de Francia
puts "\n   Nivel 2 - Regiones (Francia):"
ile_de_france = OrganizationalNode.create!(
  name: 'Île-de-France',
  code: 'IDF',
  description: 'Región de París',
  organizational_level: levels['Región'],
  parent: francia
)
puts "      ✓ #{ile_de_france.name}"

provence = OrganizationalNode.create!(
  name: 'Provence-Alpes-Côte d\'Azur',
  code: 'PAC',
  description: 'Región del sureste',
  organizational_level: levels['Región'],
  parent: francia
)
puts "      ✓ #{provence.name}"

# Nivel 3: Ciudades
puts "\n   Nivel 3 - Ciudades:"

# Ciudades de Madrid
madrid_ciudad = OrganizationalNode.create!(
  name: 'Madrid',
  code: 'MAD-C',
  description: 'Ciudad de Madrid',
  organizational_level: levels['Ciudad'],
  parent: comunidad_madrid
)
puts "      ✓ #{madrid_ciudad.name}"

alcobendas = OrganizationalNode.create!(
  name: 'Alcobendas',
  code: 'ALC',
  description: 'Alcobendas',
  organizational_level: levels['Ciudad'],
  parent: comunidad_madrid
)
puts "      ✓ #{alcobendas.name}"

# Ciudades de Cataluña
barcelona = OrganizationalNode.create!(
  name: 'Barcelona',
  code: 'BCN',
  description: 'Ciudad de Barcelona',
  organizational_level: levels['Ciudad'],
  parent: cataluna
)
puts "      ✓ #{barcelona.name}"

girona = OrganizationalNode.create!(
  name: 'Girona',
  code: 'GIR',
  description: 'Ciudad de Girona',
  organizational_level: levels['Ciudad'],
  parent: cataluna
)
puts "      ✓ #{girona.name}"

# Ciudades de Andalucía
sevilla = OrganizationalNode.create!(
  name: 'Sevilla',
  code: 'SEV',
  description: 'Ciudad de Sevilla',
  organizational_level: levels['Ciudad'],
  parent: andalucia
)
puts "      ✓ #{sevilla.name}"

malaga = OrganizationalNode.create!(
  name: 'Málaga',
  code: 'MAL',
  description: 'Ciudad de Málaga',
  organizational_level: levels['Ciudad'],
  parent: andalucia
)
puts "      ✓ #{malaga.name}"

# Ciudades de Francia
paris = OrganizationalNode.create!(
  name: 'París',
  code: 'PAR',
  description: 'Ciudad de París',
  organizational_level: levels['Ciudad'],
  parent: ile_de_france
)
puts "      ✓ #{paris.name}"

marseille = OrganizationalNode.create!(
  name: 'Marsella',
  code: 'MAR',
  description: 'Ciudad de Marsella',
  organizational_level: levels['Ciudad'],
  parent: provence
)
puts "      ✓ #{marseille.name}"

# Nivel 4: Departamentos
puts "\n   Nivel 4 - Departamentos:"

departments_data = [
  # Madrid
  { name: 'Logística Madrid', code: 'LOG-MAD', parent: madrid_ciudad },
  { name: 'Ventas Madrid', code: 'VEN-MAD', parent: madrid_ciudad },
  { name: 'Operaciones Madrid', code: 'OPS-MAD', parent: madrid_ciudad },

  # Barcelona
  { name: 'Logística Barcelona', code: 'LOG-BCN', parent: barcelona },
  { name: 'Ventas Barcelona', code: 'VEN-BCN', parent: barcelona },
  { name: 'Operaciones Barcelona', code: 'OPS-BCN', parent: barcelona },

  # Sevilla
  { name: 'Logística Sevilla', code: 'LOG-SEV', parent: sevilla },
  { name: 'Ventas Sevilla', code: 'VEN-SEV', parent: sevilla },

  # París
  { name: 'Logistique Paris', code: 'LOG-PAR', parent: paris },
  { name: 'Ventes Paris', code: 'VEN-PAR', parent: paris },

  # Marsella
  { name: 'Logistique Marseille', code: 'LOG-MAR', parent: marseille },

  # Otras ciudades
  { name: 'Operaciones Málaga', code: 'OPS-MAL', parent: malaga },
  { name: 'Operaciones Girona', code: 'OPS-GIR', parent: girona },
  { name: 'Operaciones Alcobendas', code: 'OPS-ALC', parent: alcobendas }
]

departments = []
departments_data.each do |data|
  dept = OrganizationalNode.create!(
    name: data[:name],
    code: data[:code],
    description: "Departamento de #{data[:name]}",
    organizational_level: levels['Departamento'],
    parent: data[:parent]
  )
  departments << dept
  puts "      ✓ #{dept.name}"
end

# Nivel 5: CECOs
puts "\n   Nivel 5 - CECOs (Centros de Costo):"

cecos = []
departments.each_with_index do |dept, index|
  # Crear 2-3 CECOs por departamento
  num_cecos = [ 2, 3 ].sample

  num_cecos.times do |i|
    ceco_number = (index * 10 + i + 1).to_s.rjust(4, '0')
    ceco = OrganizationalNode.create!(
      name: "CECO-#{ceco_number}",
      code: ceco_number,
      description: "Centro de costos #{ceco_number}",
      organizational_level: levels['CECO'],
      parent: dept
    )
    cecos << ceco
  end
end

puts "      ✓ #{cecos.count} CECOs creados"

# ============================================================================
# CREAR USUARIOS
# ============================================================================
puts "\n👥 Creando usuarios..."

users_data = [
  # Administradores
  { first_name: 'Carlos', last_name: 'García', email: 'carlos.garcia@company.com', phone: '+34 600 111 111' },
  { first_name: 'María', last_name: 'López', email: 'maria.lopez@company.com', phone: '+34 600 222 222' },

  # Gerentes Regionales
  { first_name: 'Juan', last_name: 'Martínez', email: 'juan.martinez@company.com', phone: '+34 600 333 333' },
  { first_name: 'Ana', last_name: 'Rodríguez', email: 'ana.rodriguez@company.com', phone: '+34 600 444 444' },
  { first_name: 'Pedro', last_name: 'Sánchez', email: 'pedro.sanchez@company.com', phone: '+34 600 555 555' },

  # Gerentes de Ciudad
  { first_name: 'Laura', last_name: 'Fernández', email: 'laura.fernandez@company.com', phone: '+34 600 666 666' },
  { first_name: 'David', last_name: 'González', email: 'david.gonzalez@company.com', phone: '+34 600 777 777' },
  { first_name: 'Carmen', last_name: 'Ruiz', email: 'carmen.ruiz@company.com', phone: '+34 600 888 888' },
  { first_name: 'Miguel', last_name: 'Torres', email: 'miguel.torres@company.com', phone: '+34 600 999 999' },

  # Gerentes de Departamento
  { first_name: 'Isabel', last_name: 'Jiménez', email: 'isabel.jimenez@company.com', phone: '+34 601 111 111' },
  { first_name: 'Francisco', last_name: 'Moreno', email: 'francisco.moreno@company.com', phone: '+34 601 222 222' },
  { first_name: 'Rosa', last_name: 'Álvarez', email: 'rosa.alvarez@company.com', phone: '+34 601 333 333' },
  { first_name: 'Antonio', last_name: 'Romero', email: 'antonio.romero@company.com', phone: '+34 601 444 444' },

  # Supervisores de CECO
  { first_name: 'Lucía', last_name: 'Navarro', email: 'lucia.navarro@company.com', phone: '+34 601 555 555' },
  { first_name: 'Javier', last_name: 'Gutiérrez', email: 'javier.gutierrez@company.com', phone: '+34 601 666 666' },
  { first_name: 'Elena', last_name: 'Serrano', email: 'elena.serrano@company.com', phone: '+34 601 777 777' },
  { first_name: 'Roberto', last_name: 'Blanco', email: 'roberto.blanco@company.com', phone: '+34 601 888 888' },

  # Francia
  { first_name: 'Sophie', last_name: 'Dubois', email: 'sophie.dubois@company.fr', phone: '+33 6 11 11 11 11' },
  { first_name: 'Pierre', last_name: 'Martin', email: 'pierre.martin@company.fr', phone: '+33 6 22 22 22 22' },
  { first_name: 'Marie', last_name: 'Bernard', email: 'marie.bernard@company.fr', phone: '+33 6 33 33 33 33' }
]

users = []
users_data.each do |data|
  user = User.create!(data)
  users << user
  puts "   ✓ #{user.full_name} (#{user.email})"
end

# ============================================================================
# ASIGNAR ACCESOS A USUARIOS
# ============================================================================
puts "\n🔐 Asignando accesos a usuarios..."

admin_user = users[0]

# Administradores: acceso a nivel país
[ users[0], users[1] ].each do |user|
  NodeUserAccess.create!(
    user: user,
    organizational_node: espana,
    granted_by: admin_user,
    granted_at: Time.current - rand(90).days
  )
  puts "   ✓ #{user.full_name} → Acceso a #{espana.name} (País completo)"
end

# Gerente Regional Madrid
NodeUserAccess.create!(
  user: users[2],
  organizational_node: comunidad_madrid,
  granted_by: admin_user,
  granted_at: Time.current - rand(60).days
)
puts "   ✓ #{users[2].full_name} → Acceso a #{comunidad_madrid.name} (Región)"

# Gerente Regional Cataluña
NodeUserAccess.create!(
  user: users[3],
  organizational_node: cataluna,
  granted_by: admin_user,
  granted_at: Time.current - rand(60).days
)
puts "   ✓ #{users[3].full_name} → Acceso a #{cataluna.name} (Región)"

# Gerente Regional Andalucía
NodeUserAccess.create!(
  user: users[4],
  organizational_node: andalucia,
  granted_by: admin_user,
  granted_at: Time.current - rand(60).days
)
puts "   ✓ #{users[4].full_name} → Acceso a #{andalucia.name} (Región)"

# Gerentes de Ciudad
NodeUserAccess.create!(user: users[5], organizational_node: madrid_ciudad, granted_by: admin_user)
NodeUserAccess.create!(user: users[6], organizational_node: barcelona, granted_by: admin_user)
NodeUserAccess.create!(user: users[7], organizational_node: sevilla, granted_by: admin_user)
NodeUserAccess.create!(user: users[8], organizational_node: malaga, granted_by: admin_user)

puts "   ✓ Gerentes de ciudad asignados"

# Gerentes de Departamento (acceso a departamentos específicos)
dept_managers = users[9..12]
dept_managers.each_with_index do |user, index|
  dept = departments[index * 3] # Asignar a un departamento
  NodeUserAccess.create!(
    user: user,
    organizational_node: dept,
    granted_by: admin_user,
    granted_at: Time.current - rand(30).days
  )
end

puts "   ✓ Gerentes de departamento asignados"

# Supervisores de CECO (acceso a CECOs específicos)
ceco_supervisors = users[13..16]
ceco_supervisors.each_with_index do |user, index|
  # Asignar 2-3 CECOs a cada supervisor
  assigned_cecos = cecos.sample(rand(2..3))
  assigned_cecos.each do |ceco|
    NodeUserAccess.create!(
      user: user,
      organizational_node: ceco,
      granted_by: admin_user,
      granted_at: Time.current - rand(20).days
    )
  end
end

puts "   ✓ Supervisores de CECO asignados"

# Usuarios de Francia
NodeUserAccess.create!(user: users[17], organizational_node: francia, granted_by: admin_user)
NodeUserAccess.create!(user: users[18], organizational_node: paris, granted_by: admin_user)
NodeUserAccess.create!(user: users[19], organizational_node: marseille, granted_by: admin_user)

puts "   ✓ Usuarios de Francia asignados"

# ============================================================================
# CREAR VEHÍCULOS
# ============================================================================
puts "\n🚗 Creando vehículos..."

brands = [ 'Toyota', 'Ford', 'Volkswagen', 'Renault', 'Seat', 'Peugeot', 'Mercedes-Benz', 'BMW', 'Audi', 'Hyundai' ]
models = {
  'Toyota' => [ 'Corolla', 'RAV4', 'Yaris', 'Hilux', 'Camry' ],
  'Ford' => [ 'Focus', 'Fiesta', 'Mondeo', 'Transit', 'Kuga' ],
  'Volkswagen' => [ 'Golf', 'Passat', 'Tiguan', 'Polo', 'Touareg' ],
  'Renault' => [ 'Clio', 'Megane', 'Captur', 'Kadjar', 'Scenic' ],
  'Seat' => [ 'Ibiza', 'León', 'Ateca', 'Arona', 'Tarraco' ],
  'Peugeot' => [ '208', '308', '3008', '5008', 'Partner' ],
  'Mercedes-Benz' => [ 'Clase A', 'Clase C', 'GLA', 'GLC', 'Vito' ],
  'BMW' => [ 'Serie 1', 'Serie 3', 'X1', 'X3', 'Serie 5' ],
  'Audi' => [ 'A3', 'A4', 'Q3', 'Q5', 'A6' ],
  'Hyundai' => [ 'i30', 'Tucson', 'Kona', 'Santa Fe', 'i20' ]
}

years = (2018..2024).to_a

# Generar matrículas españolas realistas
def generate_spanish_plate(index)
  # Formato: 1234 ABC
  number = (1000 + index).to_s
  letters = ('A'..'Z').to_a.sample(3).join
  "#{number}#{letters}"
end

# Generar matrículas francesas realistas
def generate_french_plate(index)
  # Formato: AB-123-CD
  letters1 = ('A'..'Z').to_a.sample(2).join
  number = (100 + index).to_s
  letters2 = ('A'..'Z').to_a.sample(2).join
  "#{letters1}-#{number}-#{letters2}"
end

# Generar VIN realista
def generate_vin(index)
  chars = ('A'..'Z').to_a + (0..9).to_a
  prefix = "WVW"
  suffix = chars.sample(14).join
  "#{prefix}#{suffix}"
end

vehicles_count = 0

# Distribuir vehículos en los CECOs (nivel más bajo)
cecos.each_with_index do |ceco, ceco_index|
  num_vehicles = rand(3..8) # Entre 3 y 8 vehículos por CECO

  num_vehicles.times do |i|
    brand = brands.sample
    model = models[brand].sample
    year = years.sample

    # Determinar si es España o Francia basado en el CECO
    is_france = ceco.ancestors.any? { |a| a.name == 'Francia' }

    plate = is_france ?
            generate_french_plate(vehicles_count) :
            generate_spanish_plate(vehicles_count)

    vehicle = Vehicle.create!(
      plate: plate,
      brand: brand,
      model: model,
      year: year,
      vin: generate_vin(vehicles_count),
      description: "#{brand} #{model} asignado a #{ceco.name}",
      organizational_node: ceco
    )

    vehicles_count += 1
  end
end

puts "   ✓ #{vehicles_count} vehículos creados y asignados a CECOs"

# Algunos vehículos en departamentos (no solo en CECOs)
departments.sample(5).each_with_index do |dept, index|
  brand = brands.sample
  model = models[brand].sample

  is_france = dept.ancestors.any? { |a| a.name == 'Francia' }
  plate = is_france ?
          generate_french_plate(vehicles_count + index) :
          generate_spanish_plate(vehicles_count + index)

  Vehicle.create!(
    plate: plate,
    brand: brand,
    model: model,
    year: years.sample,
    vin: generate_vin(vehicles_count + index),
    description: "Vehículo de gestión del #{dept.name}",
    organizational_node: dept
  )
end

vehicles_count += 5
puts "   ✓ 5 vehículos adicionales asignados a departamentos"

# ============================================================================
# RESUMEN
# ============================================================================
puts "\n" + "=" * 80
puts "✅ Seeds completados exitosamente!"
puts "=" * 80

puts "\n📊 Resumen de datos creados:"
puts "   • Niveles organizacionales: #{OrganizationalLevel.count}"
puts "   • Nodos organizacionales: #{OrganizationalNode.count}"
puts "     - Países: #{OrganizationalNode.where(organizational_level: levels['País']).count}"
puts "     - Regiones: #{OrganizationalNode.where(organizational_level: levels['Región']).count}"
puts "     - Ciudades: #{OrganizationalNode.where(organizational_level: levels['Ciudad']).count}"
puts "     - Departamentos: #{OrganizationalNode.where(organizational_level: levels['Departamento']).count}"
puts "     - CECOs: #{OrganizationalNode.where(organizational_level: levels['CECO']).count}"
puts "   • Usuarios: #{User.count}"
puts "   • Accesos asignados: #{NodeUserAccess.count}"
puts "   • Vehículos: #{Vehicle.count}"

puts "\n🌳 Estructura jerárquica:"
puts "   España"
puts "   ├── Comunidad de Madrid → Madrid, Alcobendas → Departamentos → CECOs"
puts "   ├── Cataluña → Barcelona, Girona → Departamentos → CECOs"
puts "   └── Andalucía → Sevilla, Málaga → Departamentos → CECOs"
puts "   Francia"
puts "   ├── Île-de-France → París → Departamentos → CECOs"
puts "   └── Provence → Marsella → Departamentos → CECOs"

puts "\n👥 Usuarios de ejemplo:"
puts "   • Administradores (acceso España completo):"
puts "     - carlos.garcia@company.com"
puts "     - maria.lopez@company.com"
puts "   • Gerentes Regionales:"
puts "     - juan.martinez@company.com (Comunidad de Madrid)"
puts "     - ana.rodriguez@company.com (Cataluña)"
puts "   • Gerentes de Ciudad:"
puts "     - laura.fernandez@company.com (Madrid)"
puts "     - david.gonzalez@company.com (Barcelona)"

puts "\n🔍 Consultas útiles para probar:"
puts "   # Ver árbol completo"
puts "   OrganizationalNodes::TreeBuilder.new.call"
puts ""
puts "   # Ver vehículos visibles para un usuario"
puts "   user = User.find_by(email: 'carlos.garcia@company.com')"
puts "   user.visible_vehicles"
puts ""
puts "   # Calcular visibilidad"
puts "   calculator = UserAccess::VisibilityCalculator.new(user)"
puts "   calculator.visibility_scope"

puts "\n" + "=" * 80
puts "🚀 ¡Listo para probar el sistema!"
puts "=" * 80
