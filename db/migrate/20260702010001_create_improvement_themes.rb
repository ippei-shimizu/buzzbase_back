class CreateImprovementThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :improvement_themes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category
      t.text :purpose
      t.string :status, null: false, default: 'open'
      t.date :started_on, null: false
      t.date :achieved_on
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :improvement_themes, %i[user_id status]
  end
end
