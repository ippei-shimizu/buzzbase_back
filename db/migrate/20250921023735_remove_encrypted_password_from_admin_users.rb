class RemoveEncryptedPasswordFromAdminUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :admin_users, :encrypted_password, :string if column_exists?(:admin_users, :encrypted_password)
  end
end
