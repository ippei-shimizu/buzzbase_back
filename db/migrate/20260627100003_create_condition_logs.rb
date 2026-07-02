class CreateConditionLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :condition_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.integer :fatigue_level                    # 1-4（悪い→良い）
      t.integer :physical_level                   # 1-4
      t.decimal :sleep_hours, precision: 4, scale: 1
      t.string :mood                              # 好調/普通/不調 等のチップ値
      t.text :memo
      t.jsonb :injuries, null: false, default: [] # [{part, memo}]
      t.timestamps
    end

    add_index :condition_logs, %i[user_id logged_on], unique: true
  end
end
