class AddKindToGoals < ActiveRecord::Migration[7.1]
  def change
    # 数値目標(numeric)と、達成/未達で管理する定性・チーム目標(qualitative)を区別する。
    add_column :goals, :kind, :string, null: false, default: 'numeric'
    # 定性目標は指標・目標値を持たないため NULL を許容する。
    change_column_null :goals, :metric_key, true
    change_column_null :goals, :target_value, true
  end
end
