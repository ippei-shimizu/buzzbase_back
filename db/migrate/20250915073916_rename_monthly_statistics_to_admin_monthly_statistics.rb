class RenameMonthlyStatisticsToAdminMonthlyStatistics < ActiveRecord::Migration[7.0]
  def change
    rename_table :monthly_statistics, :admin_monthly_statistics
  end
end
