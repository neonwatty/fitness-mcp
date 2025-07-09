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

ActiveRecord::Schema[8.0].define(version: 2025_07_09_180421) do
  create_table "api_keys", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.string "api_key_hash"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "api_key_value"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "set_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "exercise"
    t.integer "reps"
    t.decimal "weight"
    t.datetime "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_set_entries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "workout_assignments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "assignment_name"
    t.datetime "scheduled_for"
    t.text "config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workout_assignments_on_user_id"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "set_entries", "users"
  add_foreign_key "workout_assignments", "users"
end
