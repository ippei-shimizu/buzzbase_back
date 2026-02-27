class AddStatusToRelationships < ActiveRecord::Migration[7.0]
  def change
    add_column :relationships, :status, :integer, default: 1, null: false
    add_index :relationships, %i[followed_id status]
  end
end
