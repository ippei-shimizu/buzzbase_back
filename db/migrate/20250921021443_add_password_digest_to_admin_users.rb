class AddPasswordDigestToAdminUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :admin_users, :password_digest, :string unless column_exists?(:admin_users, :password_digest)
  end
end
