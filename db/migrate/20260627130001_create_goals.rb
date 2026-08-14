class CreateGoals < ActiveRecord::Migration[7.1]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :period_type, null: false # season / monthly
      t.references :season, null: true, foreign_key: { on_delete: :nullify }
      t.date :month_start
      t.date :deadline, null: false
      t.string :metric_key, null: false
      t.float :target_value, null: false
      t.string :comparison_type, null: false, default: 'greater_than'
      t.float :achieved_value
      t.datetime :achieved_at
      t.boolean :is_achieved, null: false, default: false
      t.boolean :is_finalized, null: false, default: false
      t.timestamps
    end

    add_index :goals, %i[user_id period_type is_finalized]
  end
end
