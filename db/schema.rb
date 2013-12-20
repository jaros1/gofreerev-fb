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

ActiveRecord::Schema.define(version: 20131219154446) do

  create_table "ajax_comments", force: true do |t|
    t.string   "user_id",    limit: 40, null: false
    t.string   "comment_id", limit: 20, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "ajax_comments", ["user_id"], name: "index_ajax_comments_on_user_id"

  create_table "api_gifts", force: true do |t|
    t.string   "gift_id",                     limit: 20
    t.string   "provider",                    limit: 20
    t.string   "user_id_giver",               limit: 40
    t.string   "user_id_receiver",            limit: 40
    t.string   "picture",                     limit: 1
    t.text     "api_gift_id"
    t.text     "api_picture_url"
    t.text     "api_picture_url_updated_at"
    t.text     "api_picture_url_on_error_at"
    t.string   "deleted_at_api",              limit: 1
    t.text     "balance_giver"
    t.text     "balance_receiver"
    t.text     "balance_doc_giver"
    t.text     "balance_doc_receiver"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "deep_link_id",                limit: 30
    t.integer  "deep_link_errors"
  end

  add_index "api_gifts", ["gift_id", "provider"], name: "index_api_gifts_on_gift_id", unique: true
  add_index "api_gifts", ["user_id_giver"], name: "index_api_gifts_on_giver"
  add_index "api_gifts", ["user_id_receiver"], name: "index_api_gifts_on_receiver"

  create_table "comments", force: true do |t|
    t.string   "comment_id",       limit: 20, null: false
    t.text     "comment",                     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "gift_id",          limit: 20
    t.text     "currency"
    t.text     "price"
    t.string   "new_deal_yn",      limit: 1
    t.string   "accepted_yn",      limit: 1
    t.integer  "status_update_at",            null: false
    t.datetime "deleted_at"
    t.string   "user_id",          limit: 40, null: false
  end

  add_index "comments", ["comment_id"], name: "index_comments_on_comment_id", unique: true
  add_index "comments", ["gift_id"], name: "index_comments_on_gift_id"
  add_index "comments", ["user_id"], name: "index_comments_on_user_id"

  create_table "comments_notifications", id: false, force: true do |t|
    t.integer "comment_id"
    t.integer "notification_id"
  end

  add_index "comments_notifications", ["comment_id", "notification_id"], name: "index_comment_notifications_on_comment_id", unique: true
  add_index "comments_notifications", ["notification_id"], name: "index_comment_notifications_on_notification_id"

  create_table "exchange_rates", force: true do |t|
    t.string   "from_currency", limit: 3, null: false
    t.string   "to_currency",   limit: 3, null: false
    t.decimal  "exchange_rate"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "date",          limit: 8, null: false
  end

  add_index "exchange_rates", ["from_currency", "to_currency", "date"], name: "index_exchange_rates_pk", unique: true

  create_table "friends", force: true do |t|
    t.string   "user_id_giver",    limit: 40
    t.string   "user_id_receiver", limit: 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "api_friend"
    t.text     "app_friend"
    t.string   "friend_id",        limit: 20
  end

  add_index "friends", ["friend_id"], name: "index_friends_on_friend_id", unique: true
  add_index "friends", ["user_id_giver", "user_id_receiver"], name: "index_friends_on_giver", unique: true
  add_index "friends", ["user_id_receiver", "user_id_giver"], name: "index_friends_on_receiver", unique: true

  create_table "gift_likes", force: true do |t|
    t.string   "gift_like_id", limit: 20, null: false
    t.string   "gift_id",      limit: 20, null: false
    t.text     "like"
    t.text     "show"
    t.text     "follow"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "user_id",      limit: 40, null: false
  end

  add_index "gift_likes", ["gift_id", "user_id"], name: "index_gift_lines_on_gift_id", unique: true
  add_index "gift_likes", ["user_id"], name: "index_gift_lines_on_user_id"

  create_table "gifts", force: true do |t|
    t.string   "gift_id",               limit: 20
    t.text     "description",                      null: false
    t.text     "currency",                         null: false
    t.text     "price"
    t.text     "received_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status_update_at",                 null: false
    t.datetime "deleted_at"
    t.string   "temp_picture_filename", limit: 20
    t.string   "direction",             limit: 10
    t.string   "created_by",            limit: 10
  end

  add_index "gifts", ["gift_id"], name: "index_gifts_on_gift_id", unique: true

  create_table "notifications", force: true do |t|
    t.string   "noti_id",      limit: 20, null: false
    t.string   "to_user_id",   limit: 40, null: false
    t.string   "from_user_id", limit: 40
    t.string   "internal",     limit: 1,  null: false
    t.text     "noti_key",                null: false
    t.text     "noti_options"
    t.string   "noti_read",    limit: 1,  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "notifications", ["noti_id"], name: "index_noti_on_noti_id", unique: true
  add_index "notifications", ["to_user_id"], name: "index_noti_on_to_user_id"

  create_table "sequences", force: true do |t|
    t.string   "name",       null: false
    t.integer  "value",      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sequences", ["name"], name: "index_sequences_on_name", unique: true

  create_table "tasks", force: true do |t|
    t.string   "session_id", limit: 32,               null: false
    t.text     "task",                                null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "priority",              default: 5
    t.string   "ajax",       limit: 1,  default: "Y"
    t.text     "task_data"
  end

  add_index "tasks", ["session_id"], name: "index_tasks_on_session_id"

  create_table "users", force: true do |t|
    t.string   "user_id",              limit: 40
    t.text     "user_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "currency"
    t.text     "balance"
    t.date     "balance_at"
    t.text     "permissions"
    t.string   "profile_picture_name", limit: 10
    t.text     "no_api_friends"
    t.text     "negative_interest"
    t.integer  "user_combination"
  end

  add_index "users", ["user_combination"], name: "index_users_user_combination"
  add_index "users", ["user_id"], name: "index_users_on_user_id", unique: true

end
