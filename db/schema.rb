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

ActiveRecord::Schema[7.1].define(version: 2026_05_24_111501) do
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
    t.index ["game_result_id"], name: "index_batting_averages_on_game_result_id", unique: true
    t.index ["user_id"], name: "index_batting_averages_on_user_id"
  end

  create_table "device_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "platform", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_device_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_device_tokens_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "game_results", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "match_result_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batting_average_id"
    t.bigint "pitching_result_id"
    t.bigint "season_id"
    t.index ["batting_average_id"], name: "index_game_results_on_batting_average_id"
    t.index ["match_result_id"], name: "index_game_results_on_match_result_id"
    t.index ["pitching_result_id"], name: "index_game_results_on_pitching_result_id"
    t.index ["season_id"], name: "index_game_results_on_season_id"
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

  create_table "group_invite_links", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "inviter_id", null: false
    t.string "code", limit: 8, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_group_invite_links_on_code", unique: true
    t.index ["group_id", "is_active"], name: "index_group_invite_links_on_group_id_and_is_active"
    t.index ["group_id"], name: "index_group_invite_links_on_group_id"
    t.index ["inviter_id"], name: "index_group_invite_links_on_inviter_id"
  end

  create_table "group_ranking_snapshots", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "user_id", null: false
    t.string "stat_type", null: false
    t.integer "rank", null: false
    t.decimal "value", precision: 10, scale: 3, null: false
    t.date "snapshot_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "user_id", "stat_type", "snapshot_date"], name: "idx_group_ranking_snapshots_unique", unique: true
    t.index ["group_id"], name: "index_group_ranking_snapshots_on_group_id"
    t.index ["snapshot_date"], name: "index_group_ranking_snapshots_on_snapshot_date"
    t.index ["user_id"], name: "index_group_ranking_snapshots_on_user_id"
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

  create_table "management_notices", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.integer "status", default: 0, null: false
    t.datetime "published_at"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "notified_at"
    t.index ["status", "published_at"], name: "index_management_notices_on_status_and_published_at"
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
    t.integer "inning_format", default: 9, null: false
    t.string "appearance_type", default: "starter", null: false
    t.index ["game_result_id"], name: "index_match_results_on_game_result_id_unique", unique: true, where: "(game_result_id IS NOT NULL)"
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
    t.integer "hit_direction_id"
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

  create_table "seasons", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_seasons_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_seasons_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "free", null: false
    t.string "plan_type"
    t.string "platform"
    t.string "product_id"
    t.datetime "started_at"
    t.datetime "expires_at"
    t.datetime "cancelled_at"
    t.datetime "refunded_at"
    t.datetime "billing_issue_at"
    t.boolean "has_used_trial", default: false, null: false
    t.string "revenuecat_user_id"
    t.string "revenuecat_entitlement_id"
    t.boolean "is_early_subscriber", default: false, null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.index ["expires_at"], name: "index_subscriptions_on_expires_at"
    t.index ["revenuecat_user_id"], name: "index_subscriptions_on_revenuecat_user_id", unique: true
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
    t.index ["user_id"], name: "index_subscriptions_on_user_id", unique: true
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

  create_table "user_subscription_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "subscription_id"
    t.string "event_type", null: false
    t.string "platform"
    t.string "product_id"
    t.string "period_type"
    t.datetime "occurred_at", null: false
    t.jsonb "raw_payload"
    t.string "revenuecat_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_user_subscription_events_on_event_type"
    t.index ["revenuecat_event_id"], name: "index_user_subscription_events_on_revenuecat_event_id", unique: true
    t.index ["subscription_id"], name: "index_user_subscription_events_on_subscription_id"
    t.index ["user_id", "occurred_at"], name: "index_user_subscription_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_user_subscription_events_on_user_id"
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
    t.datetime "last_management_notice_read_at"
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

  create_table "webhook_events", force: :cascade do |t|
    t.string "provider", null: false
    t.string "external_event_id", null: false
    t.string "event_type"
    t.datetime "received_at", null: false
    t.datetime "processed_at"
    t.string "status", default: "pending", null: false
    t.jsonb "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.index ["provider", "external_event_id"], name: "index_webhook_events_on_provider_and_external_event_id", unique: true
    t.index ["status"], name: "index_webhook_events_on_status"
  end

  add_foreign_key "admin_refresh_tokens", "admin_users"
  add_foreign_key "baseball_notes", "users"
  add_foreign_key "batting_averages", "users"
  add_foreign_key "device_tokens", "users"
  add_foreign_key "game_results", "batting_averages"
  add_foreign_key "game_results", "match_results", on_delete: :cascade
  add_foreign_key "game_results", "pitching_results"
  add_foreign_key "game_results", "seasons", on_delete: :nullify
  add_foreign_key "game_results", "users"
  add_foreign_key "group_invitations", "groups"
  add_foreign_key "group_invitations", "users"
  add_foreign_key "group_invite_links", "groups"
  add_foreign_key "group_invite_links", "users", column: "inviter_id"
  add_foreign_key "group_ranking_snapshots", "groups"
  add_foreign_key "group_ranking_snapshots", "users"
  add_foreign_key "group_users", "groups"
  add_foreign_key "group_users", "users"
  add_foreign_key "management_notices", "admin_users", column: "created_by_id"
  add_foreign_key "match_results", "teams", column: "my_team_id"
  add_foreign_key "match_results", "teams", column: "opponent_team_id"
  add_foreign_key "match_results", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "pitching_results", "users"
  add_foreign_key "plate_appearances", "game_results", on_delete: :cascade
  add_foreign_key "plate_appearances", "users"
  add_foreign_key "seasons", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscriptions", "users"
  add_foreign_key "teams", "baseball_categories", column: "category_id"
  add_foreign_key "teams", "prefectures"
  add_foreign_key "user_awards", "awards"
  add_foreign_key "user_awards", "users"
  add_foreign_key "user_notifications", "notifications"
  add_foreign_key "user_notifications", "users"
  add_foreign_key "user_positions", "positions"
  add_foreign_key "user_positions", "users"
  add_foreign_key "user_subscription_events", "subscriptions"
  add_foreign_key "user_subscription_events", "users"
end
