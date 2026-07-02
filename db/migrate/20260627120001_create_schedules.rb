class CreateSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :days_of_week, null: false       # "1,3,5"（月=1〜日=7）
      t.time :scheduled_time, null: false
      t.text :note
      t.boolean :notification_enabled, null: false, default: true
      t.boolean :active, null: false, default: true
      t.string :notification_message            # カスタム通知文（Pro）
      t.timestamps
    end

    add_index :schedules, %i[user_id active]
  end
end
