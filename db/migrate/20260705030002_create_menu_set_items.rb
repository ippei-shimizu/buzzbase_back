class CreateMenuSetItems < ActiveRecord::Migration[7.1]
  def change
    create_table :menu_set_items do |t|
      t.references :menu_set, null: false, foreign_key: true
      t.references :practice_menu, null: false, foreign_key: true
      t.float :target_value
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
  end
end
