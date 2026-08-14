class CreateGoalBadges < ActiveRecord::Migration[7.1]
  def change
    create_table :goal_badges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true
      t.string :badge_type, null: false
      t.string :badge_name, null: false
      t.datetime :awarded_at, null: false
      t.timestamps
    end
  end
end
