class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.date :activity_date, null: false
      t.integer :practice_menu_count, null: false, default: 0  # distinct メニュー数
      t.integer :total_swing_count, null: false, default: 0
      t.boolean :has_game, null: false, default: false
      t.integer :intensity_level, null: false, default: 0      # 0-4
      t.timestamps
    end

    add_index :activity_logs, %i[user_id activity_date], unique: true
  end
end
