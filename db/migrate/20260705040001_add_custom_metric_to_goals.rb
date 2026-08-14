class AddCustomMetricToGoals < ActiveRecord::Migration[7.1]
  def change
    # 自由指標(kind: manual)の目標。アプリが自動集計しない値をユーザーが定義し、
    # 現在値(manual_current_value)を手入力で更新する。
    change_table :goals, bulk: true do |t|
      t.string :custom_metric_label
      t.string :custom_unit
      t.float :manual_current_value, null: false, default: 0
    end
  end
end
