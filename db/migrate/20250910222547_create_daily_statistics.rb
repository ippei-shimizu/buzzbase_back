class CreateDailyStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :daily_statistics do |t|
      t.date :date, null: false
      t.integer :total_users, default: 0, null: false
      t.integer :active_users, default: 0, null: false
      t.integer :new_users, default: 0, null: false
      t.integer :total_games, default: 0, null: false
      t.integer :total_posts, default: 0, null: false

      t.timestamps null: false
    end
    add_index :daily_statistics, :date, unique: true
  end
end
