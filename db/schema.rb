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

ActiveRecord::Schema[8.0].define(version: 2025_10_17_153112) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "api_name", null: false
    t.string "api_key", null: false
    t.string "api_secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token"
    t.datetime "token_expires_at"
    t.string "oauth_state"
    t.datetime "oauth_authorized_at"
    t.string "redirect_uri"
    t.index ["api_name"], name: "index_api_configurations_on_api_name"
    t.index ["user_id", "api_name"], name: "index_api_configurations_on_user_id_and_api_name", unique: true
    t.index ["user_id"], name: "index_api_configurations_on_user_id"
  end

  create_table "holdings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "broker"
    t.string "exchange"
    t.string "trading_symbol"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_holdings_on_user_id"
  end

  create_table "instrument_histories", force: :cascade do |t|
    t.bigint "master_instrument_id", null: false
    t.integer "unit", null: false
    t.integer "interval", null: false
    t.datetime "date", null: false
    t.decimal "open", precision: 15, scale: 2
    t.decimal "high", precision: 15, scale: 2
    t.decimal "low", precision: 15, scale: 2
    t.decimal "close", precision: 15, scale: 2
    t.bigint "volume"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["master_instrument_id", "unit", "interval", "date"], name: "index_instrument_histories_unique", unique: true
    t.index ["master_instrument_id"], name: "index_instrument_histories_on_master_instrument_id"
    t.index ["unit"], name: "index_instrument_histories_on_unit"
  end

  create_table "instruments", force: :cascade do |t|
    t.string "type", null: false
    t.string "symbol"
    t.string "name"
    t.string "exchange"
    t.string "segment"
    t.string "identifier"
    t.string "exchange_token"
    t.decimal "tick_size", precision: 10, scale: 5
    t.integer "lot_size"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange"], name: "index_instruments_on_exchange"
    t.index ["identifier"], name: "index_instruments_on_identifier"
    t.index ["raw_data"], name: "index_instruments_on_raw_data", using: :gin
    t.index ["symbol"], name: "index_instruments_on_symbol"
    t.index ["type"], name: "index_instruments_on_type"
  end

  create_table "master_instruments", force: :cascade do |t|
    t.string "exchange"
    t.string "exchange_token"
    t.integer "zerodha_instrument_id"
    t.integer "upstox_instrument_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["upstox_instrument_id"], name: "index_master_instruments_on_upstox_instrument_id", unique: true
    t.index ["zerodha_instrument_id"], name: "index_master_instruments_on_zerodha_instrument_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone_number", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
  end

  add_foreign_key "api_configurations", "users"
  add_foreign_key "holdings", "users"
  add_foreign_key "instrument_histories", "master_instruments"
  add_foreign_key "sessions", "users"
end
