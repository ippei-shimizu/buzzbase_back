class AddLastManagementNoticeReadAtToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :last_management_notice_read_at, :datetime
  end
end
