class RenameDailyStatisticsToAdminDailyStatistics < ActiveRecord::Migration[7.0]
  def change
    rename_table :daily_statistics, :admin_daily_statistics
  end
end
