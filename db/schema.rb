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

ActiveRecord::Schema[7.2].define(version: 2023_11_30_210229) do
  create_table "analytics", id: :integer, charset: "utf8mb4", force: :cascade do |t|
    t.string "segment"
    t.string "action"
    t.string "bp_slice"
    t.string "ip"
    t.integer "user"
    t.text "params"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "licenses", charset: "utf8mb4", force: :cascade do |t|
    t.text "encrypted_key"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "ontologies", charset: "utf8mb4", force: :cascade do |t|
    t.string "acronym", null: false
    t.text "new_term_instructions"
    t.text "custom_message"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["acronym"], name: "index_ontologies_on_acronym", unique: true
  end

  create_table "timeouts", id: :integer, charset: "utf8mb4", force: :cascade do |t|
    t.string "path"
    t.integer "ontology_id"
    t.text "concept_id"
    t.text "params"
    t.timestamp "created"
  end

  create_table "virtual_appliance_users", id: :integer, charset: "utf8mb4", force: :cascade do |t|
    t.string "user_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end
end
