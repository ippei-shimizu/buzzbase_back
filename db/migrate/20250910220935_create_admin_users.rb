class CreateAdminUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :encrypted_password, null: false
      t.integer :role, default: 0, null: false
      t.text :permissions
      t.integer :login_count, default: 0, null: false
      t.datetime :last_login_at

      t.timestamps null: false
    end
    add_index :admin_users, :email, unique: true
    add_index :admin_users, :role
  end
end
