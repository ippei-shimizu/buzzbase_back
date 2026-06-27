class CreateShadowSwingSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :shadow_swing_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.integer :target_count, null: false
      t.integer :swing_count, null: false, default: 0
      t.datetime :completed_at
      t.references :practice_log, null: true, foreign_key: { on_delete: :nullify }
      t.timestamps
    end

    add_index :shadow_swing_sessions, %i[user_id logged_on]
  end
end
