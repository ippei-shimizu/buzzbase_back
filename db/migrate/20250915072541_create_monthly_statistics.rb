class CreateMonthlyStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :monthly_statistics do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.date :month_start_date, null: false
      t.date :month_end_date, null: false
      t.integer :total_users, null: false, default: 0
      t.decimal :avg_daily_active_users, precision: 8, scale: 2, null: false, default: 0.0
      t.integer :peak_daily_active_users, null: false, default: 0
      t.decimal :avg_weekly_active_users, precision: 8, scale: 2, null: false, default: 0.0
      t.integer :new_users, null: false, default: 0
      t.integer :total_games, null: false, default: 0
      t.integer :total_posts, null: false, default: 0
      t.integer :total_batting_records, null: false, default: 0
      t.integer :total_pitching_records, null: false, default: 0
      t.decimal :monthly_retention_rate, precision: 5, scale: 2
      t.decimal :user_growth_rate, precision: 5, scale: 2
      t.decimal :engagement_score, precision: 5, scale: 2

      t.timestamps
    end

    add_index :monthly_statistics, [:year, :month], unique: true
    add_index :monthly_statistics, :month_start_date
  end
end
