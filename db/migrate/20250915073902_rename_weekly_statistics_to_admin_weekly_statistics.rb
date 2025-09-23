class RenameWeeklyStatisticsToAdminWeeklyStatistics < ActiveRecord::Migration[7.0]
  def change
    rename_table :weekly_statistics, :admin_weekly_statistics
  end
end
