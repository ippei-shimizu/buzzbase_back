class CreateWeeklyStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :weekly_statistics do |t|
      t.date :week_start_date, null: false
      t.date :week_end_date, null: false
      t.integer :total_users, null: false, default: 0
      t.decimal :avg_daily_active_users, precision: 8, scale: 2, null: false, default: 0.0
      t.integer :peak_daily_active_users, null: false, default: 0
      t.integer :new_users, null: false, default: 0
      t.integer :total_games, null: false, default: 0
      t.integer :total_posts, null: false, default: 0
      t.integer :total_batting_records, null: false, default: 0
      t.integer :total_pitching_records, null: false, default: 0
      t.decimal :weekly_retention_rate, precision: 5, scale: 2
      t.decimal :user_growth_rate, precision: 5, scale: 2

      t.timestamps
    end

    add_index :weekly_statistics, :week_start_date, unique: true
    add_index :weekly_statistics, :week_end_date
  end
end
