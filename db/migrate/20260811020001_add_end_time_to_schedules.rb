class AddEndTimeToSchedules < ActiveRecord::Migration[7.1]
  def change
    # 終日予定・開始時刻のみの予定を許容するため nullable。
    add_column :schedules, :end_time, :time
  end
end
