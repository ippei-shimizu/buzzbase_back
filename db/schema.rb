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

ActiveRecord::Schema[7.0].define(version: 2026_02_27_134343) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_daily_statistics", force: :cascade do |t|
    t.date "date", null: false
    t.integer "total_users", default: 0, null: false
    t.integer "active_users", default: 0, null: false
    t.integer "new_users", default: 0, null: false
    t.integer "total_games", default: 0, null: false
    t.integer "total_posts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_batting_records", default: 0, null: false
    t.integer "total_pitching_records", default: 0, null: false
    t.index ["date"], name: "index_admin_daily_statistics_on_date", unique: true
  end

  create_table "admin_monthly_statistics", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "month", null: false
    t.date "month_start_date", null: false
    t.date "month_end_date", null: false
    t.integer "total_users", default: 0, null: false
    t.decimal "avg_daily_active_users", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "peak_daily_active_users", default: 0, null: false
    t.decimal "avg_weekly_active_users", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "new_users", default: 0, null: false
    t.integer "total_games", default: 0, null: false
    t.integer "total_posts", default: 0, null: false
    t.integer "total_batting_records", default: 0, null: false
    t.integer "total_pitching_records", default: 0, null: false
    t.decimal "monthly_retention_rate", precision: 5, scale: 2
    t.decimal "user_growth_rate", precision: 5, scale: 2
    t.decimal "engagement_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["month_start_date"], name: "index_admin_monthly_statistics_on_month_start_date"
    t.index ["year", "month"], name: "index_admin_monthly_statistics_on_year_and_month", unique: true
  end

  create_table "admin_refresh_tokens", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "jti", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id", "expires_at"], name: "index_admin_refresh_tokens_on_admin_user_id_and_expires_at"
    t.index ["admin_user_id"], name: "index_admin_refresh_tokens_on_admin_user_id"
    t.index ["expires_at"], name: "index_admin_refresh_tokens_on_expires_at"
    t.index ["jti"], name: "index_admin_refresh_tokens_on_jti", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "admin_weekly_statistics", force: :cascade do |t|
    t.date "week_start_date", null: false
    t.date "week_end_date", null: false
    t.integer "total_users", default: 0, null: false
    t.decimal "avg_daily_active_users", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "peak_daily_active_users", default: 0, null: false
    t.integer "new_users", default: 0, null: false
    t.integer "total_games", default: 0, null: false
    t.integer "total_posts", default: 0, null: false
    t.integer "total_batting_records", default: 0, null: false
    t.integer "total_pitching_records", default: 0, null: false
    t.decimal "weekly_retention_rate", precision: 5, scale: 2
    t.decimal "user_growth_rate", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["week_end_date"], name: "index_admin_weekly_statistics_on_week_end_date"
    t.index ["week_start_date"], name: "index_admin_weekly_statistics_on_week_start_date", unique: true
  end

  create_table "awards", force: :cascade do |t|
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "baseball_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hiragana"
    t.string "katakana"
    t.string "alphabet"
  end

  create_table "baseball_notes", force: :cascade do |t|
    t.string "title"
    t.date "date"
    t.text "memo"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_baseball_notes_on_user_id"
  end

  create_table "batting_averages", force: :cascade do |t|
    t.bigint "game_result_id", null: false
    t.bigint "user_id", null: false
    t.integer "plate_appearances"
    t.integer "times_at_bat"
    t.integer "hit"
    t.integer "two_base_hit"
    t.integer "three_base_hit"
    t.integer "home_run"
    t.integer "total_bases"
    t.integer "runs_batted_in"
    t.integer "run"
    t.integer "strike_out"
    t.integer "base_on_balls"
    t.integer "hit_by_pitch"
    t.integer "sacrifice_hit"
    t.integer "stealing_base"
    t.integer "caught_stealing"
    t.integer "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "at_bats"
    t.integer "sacrifice_fly"
    t.index ["game_result_id"], name: "index_batting_averages_on_game_result_id"
    t.index ["user_id"], name: "index_batting_averages_on_user_id"
  end

  create_table "game_results", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "match_result_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batting_average_id"
    t.bigint "pitching_result_id"
    t.index ["batting_average_id"], name: "index_game_results_on_batting_average_id"
    t.index ["match_result_id"], name: "index_game_results_on_match_result_id"
    t.index ["pitching_result_id"], name: "index_game_results_on_pitching_result_id"
    t.index ["user_id"], name: "index_game_results_on_user_id"
  end

  create_table "group_invitations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.integer "state"
    t.datetime "sent_at"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_group_invitations_on_group_id"
    t.index ["user_id"], name: "index_group_invitations_on_user_id"
  end

  create_table "group_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_group_users_on_group_id"
    t.index ["user_id"], name: "index_group_users_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "match_results", force: :cascade do |t|
    t.integer "game_result_id"
    t.bigint "user_id", null: false
    t.datetime "date_and_time", null: false
    t.string "match_type", null: false
    t.bigint "my_team_id", null: false
    t.bigint "opponent_team_id", null: false
    t.integer "my_team_score", null: false
    t.integer "opponent_team_score", null: false
    t.string "batting_order", null: false
    t.string "defensive_position", null: false
    t.integer "tournament_id"
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["my_team_id"], name: "index_match_results_on_my_team_id"
    t.index ["opponent_team_id"], name: "index_match_results_on_opponent_team_id"
    t.index ["user_id"], name: "index_match_results_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.string "event_type", null: false
    t.integer "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "read_at"
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
  end

  create_table "pitching_results", force: :cascade do |t|
    t.bigint "game_result_id", null: false
    t.bigint "user_id", null: false
    t.integer "win"
    t.integer "loss"
    t.integer "hold"
    t.integer "saves"
    t.float "innings_pitched"
    t.integer "number_of_pitches"
    t.boolean "got_to_the_distance"
    t.integer "run_allowed"
    t.integer "earned_run"
    t.integer "hits_allowed"
    t.integer "home_runs_hit"
    t.integer "strikeouts"
    t.integer "base_on_balls"
    t.integer "hit_by_pitch"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_result_id"], name: "index_pitching_results_on_game_result_id"
    t.index ["user_id"], name: "index_pitching_results_on_user_id"
  end

  create_table "plate_appearances", force: :cascade do |t|
    t.bigint "game_result_id", null: false
    t.bigint "user_id", null: false
    t.integer "batter_box_number"
    t.string "batting_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "batting_position_id"
    t.integer "plate_result_id"
    t.index ["game_result_id"], name: "index_plate_appearances_on_game_result_id"
    t.index ["user_id"], name: "index_plate_appearances_on_user_id"
  end

  create_table "positions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prefectures", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hiragana"
    t.string "katakana"
    t.string "alphabet"
  end

  create_table "relationships", force: :cascade do |t|
    t.integer "follower_id"
    t.integer "followed_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 1, null: false
    t.index ["followed_id", "status"], name: "index_relationships_on_followed_id_and_status"
    t.index ["followed_id"], name: "index_relationships_on_followed_id"
    t.index ["follower_id"], name: "index_relationships_on_follower_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "category_id"
    t.bigint "prefecture_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_teams_on_category_id"
    t.index ["prefecture_id"], name: "index_teams_on_prefecture_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_awards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "award_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["award_id"], name: "index_user_awards_on_award_id"
    t.index ["user_id"], name: "index_user_awards_on_user_id"
  end

  create_table "user_notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notification_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_id"], name: "index_user_notifications_on_notification_id"
    t.index ["user_id"], name: "index_user_notifications_on_user_id"
  end

  create_table "user_positions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "position_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position_id"], name: "index_user_positions_on_position_id"
    t.index ["user_id"], name: "index_user_positions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "name"
    t.string "image"
    t.string "email"
    t.json "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.text "introduction"
    t.text "positions"
    t.integer "team_id"
    t.datetime "last_login_at"
    t.datetime "suspended_at"
    t.datetime "deleted_at"
    t.string "suspended_reason"
    t.boolean "is_private", default: false, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_private"], name: "index_users_on_is_private"
    t.index ["last_login_at"], name: "index_users_on_last_login_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
    t.index ["user_id"], name: "index_users_on_user_id", unique: true
  end

  add_foreign_key "admin_refresh_tokens", "admin_users"
  add_foreign_key "baseball_notes", "users"
  add_foreign_key "batting_averages", "users"
  add_foreign_key "game_results", "batting_averages"
  add_foreign_key "game_results", "match_results", on_delete: :cascade
  add_foreign_key "game_results", "pitching_results"
  add_foreign_key "game_results", "users"
  add_foreign_key "group_invitations", "groups"
  add_foreign_key "group_invitations", "users"
  add_foreign_key "group_users", "groups"
  add_foreign_key "group_users", "users"
  add_foreign_key "match_results", "teams", column: "my_team_id"
  add_foreign_key "match_results", "teams", column: "opponent_team_id"
  add_foreign_key "match_results", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "pitching_results", "users"
  add_foreign_key "plate_appearances", "game_results", on_delete: :cascade
  add_foreign_key "plate_appearances", "users"
  add_foreign_key "teams", "baseball_categories", column: "category_id"
  add_foreign_key "teams", "prefectures"
  add_foreign_key "user_awards", "awards"
  add_foreign_key "user_awards", "users"
  add_foreign_key "user_notifications", "notifications"
  add_foreign_key "user_notifications", "users"
  add_foreign_key "user_positions", "positions"
  add_foreign_key "user_positions", "users"
end
