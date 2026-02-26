class AddAccountStatusToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :suspended_at, :datetime, null: true
    add_column :users, :deleted_at, :datetime, null: true
    add_column :users, :suspended_reason, :string, null: true
    add_index :users, :suspended_at
    add_index :users, :deleted_at
  end
end
