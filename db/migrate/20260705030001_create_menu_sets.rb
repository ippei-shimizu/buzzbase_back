class CreateMenuSets < ActiveRecord::Migration[7.1]
  def change
    create_table :menu_sets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :note
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :menu_sets, %i[user_id sort_order]
  end
end
