class CreateInsightCombinations < ActiveRecord::Migration[7.1]
  def change
    create_table :insight_combinations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :input_type, null: false
      t.references :practice_menu, null: true, foreign_key: true
      t.string :metric, null: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :insight_combinations, %i[user_id input_type practice_menu_id metric],
              unique: true, name: 'index_insight_combinations_uniqueness'
  end
end
