class AddDeviseTokenAuthToAdminUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :admin_users, :provider, :string, default: 'email', null: false
    add_column :admin_users, :uid, :string, null: false
    add_column :admin_users, :tokens, :text
    
    add_index :admin_users, [:uid, :provider], unique: true
  end
end
