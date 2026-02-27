class AddIsPrivateToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :is_private, :boolean, default: false, null: false
    add_index :users, :is_private
  end
end
