# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 8) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "node_user_accesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organizational_node_id", null: false
    t.datetime "granted_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "granted_by_id"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_node_user_accesses_on_discarded_at"
    t.index ["granted_by_id"], name: "index_node_user_accesses_on_granted_by_id"
    t.index ["organizational_node_id", "user_id", "discarded_at"], name: "index_node_accesses_visibility"
    t.index ["organizational_node_id"], name: "index_node_user_accesses_on_organizational_node_id"
    t.index ["user_id", "organizational_node_id"], name: "index_node_user_accesses_on_user_and_node", unique: true
    t.index ["user_id"], name: "index_node_user_accesses_on_user_id"
  end

  create_table "organizational_levels", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.text "description"
    t.integer "level_order", null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_organizational_levels_on_discarded_at"
    t.index ["level_order"], name: "index_organizational_levels_on_level_order", unique: true
    t.index ["name"], name: "index_organizational_levels_on_name"
  end

  create_table "organizational_nodes", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.text "description"
    t.string "code", limit: 50
    t.bigint "organizational_level_id", null: false
    t.string "ancestry"
    t.integer "ancestry_depth", default: 0
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry", "organizational_level_id"], name: "index_nodes_on_ancestry_and_level"
    t.index ["ancestry"], name: "index_organizational_nodes_on_ancestry"
    t.index ["code"], name: "index_organizational_nodes_on_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["discarded_at"], name: "index_organizational_nodes_on_discarded_at"
    t.index ["name"], name: "index_organizational_nodes_on_name"
    t.index ["organizational_level_id", "discarded_at"], name: "index_nodes_level_discarded"
    t.index ["organizational_level_id", "name"], name: "index_organizational_nodes_on_organizational_level_id_and_name"
    t.index ["organizational_level_id"], name: "index_organizational_nodes_on_organizational_level_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", limit: 100, null: false
    t.string "first_name", limit: 50, null: false
    t.string "last_name", limit: 50, null: false
    t.string "phone", limit: 20
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email", "discarded_at"], name: "index_users_email_discarded"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name", "last_name"], name: "index_users_on_first_name_and_last_name"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "plate", limit: 20, null: false
    t.string "brand", limit: 50
    t.string "model", limit: 50
    t.integer "year"
    t.string "vin", limit: 17
    t.text "description"
    t.bigint "organizational_node_id", null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_vehicles_on_discarded_at"
    t.index ["organizational_node_id", "discarded_at"], name: "index_vehicles_on_organizational_node_id_and_discarded_at"
    t.index ["organizational_node_id", "plate", "discarded_at"], name: "index_vehicles_node_plate_discarded"
    t.index ["organizational_node_id"], name: "index_vehicles_on_organizational_node_id"
    t.index ["plate"], name: "index_vehicles_on_plate", unique: true
    t.index ["vin"], name: "index_vehicles_on_vin", unique: true, where: "(vin IS NOT NULL)"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "node_user_accesses", "organizational_nodes"
  add_foreign_key "node_user_accesses", "users"
  add_foreign_key "node_user_accesses", "users", column: "granted_by_id"
  add_foreign_key "organizational_nodes", "organizational_levels"
  add_foreign_key "vehicles", "organizational_nodes"
end
