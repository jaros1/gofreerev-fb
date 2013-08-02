# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130802122601) do

  create_table "exchange_rates", force: true do |t|
    t.string   "from_currency",    limit: 3, null: false
    t.string   "to_currency",      limit: 3, null: false
    t.decimal  "exchange_rate"
    t.datetime "exchange_rate_at"
    t.string   "request_update",   limit: 1
    t.datetime "last_request_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "exchange_rates", ["from_currency", "to_currency"], name: "index_exchange_rates_on_from_currency_and_to_currency", unique: true

  create_table "friends", force: true do |t|
    t.string   "user_id_giver"
    t.string   "user_id_receiver"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "api_friend"
    t.text     "app_friend"
    t.string   "friend_id",        limit: 20
  end

  add_index "friends", ["friend_id"], name: "index_friends_on_friend_id", unique: true
  add_index "friends", ["user_id_giver"], name: "index_friends_on_giver"
  add_index "friends", ["user_id_receiver"], name: "index_friends_on_receiver"

  create_table "gifts", force: true do |t|
    t.string   "gift_id",              limit: 20
    t.text     "description",                     null: false
    t.text     "currency",                        null: false
    t.text     "price"
    t.string   "user_id_giver",        limit: 20
    t.string   "user_id_receiver",     limit: 20
    t.text     "received_at"
    t.date     "new_price_at"
    t.text     "new_price"
    t.text     "negative_interest"
    t.text     "social_dividend"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "api_gift_id"
    t.string   "gifttype",             limit: 1
    t.text     "social_dividend_from"
    t.text     "balance_giver"
    t.text     "balance_receiver"
    t.string   "picture",              limit: 1
    t.text     "api_picture_url"
  end

  add_index "gifts", ["gift_id"], name: "index_gifts_on_gift_id", unique: true
  add_index "gifts", ["user_id_giver"], name: "index_gifts_on_giver"
  add_index "gifts", ["user_id_receiver"], name: "index_gifts_on_receiver"

  create_table "notifications", force: true do |t|
    t.string   "noti_id",      limit: 20, null: false
    t.string   "to_user_id",   limit: 20, null: false
    t.string   "from_user_id", limit: 20
    t.string   "internal",     limit: 1,  null: false
    t.text     "noti_key",                null: false
    t.text     "noti_options"
    t.string   "noti_read",    limit: 1,  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "notifications", ["noti_id"], name: "index_noti_on_noti_id", unique: true
  add_index "notifications", ["to_user_id"], name: "index_noti_on_to_user_id"

  create_table "users", force: true do |t|
    t.string   "user_id",              limit: 20
    t.text     "user_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "currency"
    t.text     "balance"
    t.date     "balance_at"
    t.text     "permissions"
    t.string   "profile_picture_name", limit: 10
    t.integer  "timezone"
    t.text     "no_api_friends"
    t.text     "negative_interest"
  end

  add_index "users", ["user_id"], name: "index_users_on_user_id", unique: true

end
