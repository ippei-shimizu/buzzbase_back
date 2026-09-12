class CreatePracticeMenus < ActiveRecord::Migration[7.1]
  def change
    create_table :practice_menus do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false              # batting/pitching/defense/baserunning/training/other
      t.string :unit, null: false                  # count/minutes/distance
      t.string :unit_label                         # 本/球/回/分/km/m 等の表示ラベル
      t.decimal :default_value, precision: 10, scale: 2
      t.boolean :is_favorite, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :practice_menus, %i[user_id archived]
  end
end
