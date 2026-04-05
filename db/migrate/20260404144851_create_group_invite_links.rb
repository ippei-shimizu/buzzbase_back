class CreateGroupInviteLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :group_invite_links do |t|
      t.references :group, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :code, null: false, limit: 8
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    add_index :group_invite_links, :code, unique: true
    add_index :group_invite_links, %i[group_id is_active]
  end
end
