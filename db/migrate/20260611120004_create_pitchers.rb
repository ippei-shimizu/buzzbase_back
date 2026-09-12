class CreatePitchers < ActiveRecord::Migration[7.0]
  def change
    create_table :pitchers do |t|
      t.string :name, null: false
      t.references :team, null: true, foreign_key: true
      t.integer :throw_hand
      t.references :arm_angle, null: true, foreign_key: true
      t.references :velocity_zone, null: true, foreign_key: true
      t.references :pitcher_style, null: true, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :pitchers, %i[created_by_user_id team_id name], unique: true, name: 'index_pitchers_on_user_team_name'
  end
end
