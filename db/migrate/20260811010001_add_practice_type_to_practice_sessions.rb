class AddPracticeTypeToPracticeSessions < ActiveRecord::Migration[7.1]
  def change
    # 「自主練習日数」目標の集計軸。既存データは大半が個人記録なので self_practice を既定にする。
    add_column :practice_sessions, :practice_type, :string, null: false, default: 'self_practice'
  end
end
