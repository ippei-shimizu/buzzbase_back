class CreateManagementNotices < ActiveRecord::Migration[7.0]
  def change
    create_table :management_notices do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :status, null: false, default: 0
      t.datetime :published_at
      t.bigint :created_by_id, null: false

      t.timestamps
    end

    add_index :management_notices, %i[status published_at]
    add_foreign_key :management_notices, :admin_users, column: :created_by_id
  end
end
