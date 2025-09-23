class RemoveUnnecessaryColumnsFromAdminUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :admin_users, :login_count, :integer if column_exists?(:admin_users, :login_count)
    remove_column :admin_users, :last_login_at, :datetime if column_exists?(:admin_users, :last_login_at)
    remove_column :admin_users, :provider, :string if column_exists?(:admin_users, :provider)
    remove_column :admin_users, :uid, :string if column_exists?(:admin_users, :uid)
    remove_column :admin_users, :tokens, :text if column_exists?(:admin_users, :tokens)
    remove_column :admin_users, :role, :integer if column_exists?(:admin_users, :role)
    remove_column :admin_users, :permissions, :text if column_exists?(:admin_users, :permissions)
  end
end
