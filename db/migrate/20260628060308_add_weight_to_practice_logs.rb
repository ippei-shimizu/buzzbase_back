class AddWeightToPracticeLogs < ActiveRecord::Migration[7.1]
  def change
    # 筋トレ（unit=weight_reps）の重さ(kg)。回数は amount に入れる。
    add_column :practice_logs, :weight, :decimal, precision: 10, scale: 2
  end
end
