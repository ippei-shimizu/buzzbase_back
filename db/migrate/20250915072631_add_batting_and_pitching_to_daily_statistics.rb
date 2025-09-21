class AddBattingAndPitchingToDailyStatistics < ActiveRecord::Migration[7.0]
  def change
    add_column :daily_statistics, :total_batting_records, :integer, null: false, default: 0
    add_column :daily_statistics, :total_pitching_records, :integer, null: false, default: 0
  end
end
