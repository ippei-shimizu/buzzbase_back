class CreatePracticeLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :practice_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :practice_menu, null: true, foreign_key: { on_delete: :nullify }
      t.date :logged_on, null: false
      t.decimal :amount, precision: 10, scale: 2
      t.string :menu_name, null: false            # メニュー名のスナップショット（改名・削除耐性）
      t.string :unit_label                        # 単位ラベルのスナップショット
      t.string :source, null: false, default: 'manual' # manual/shadow_swing
      t.text :memo
      t.timestamps
    end

    add_index :practice_logs, %i[user_id logged_on]
  end
end
