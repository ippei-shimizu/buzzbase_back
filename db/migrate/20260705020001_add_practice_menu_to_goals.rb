class AddPracticeMenuToGoals < ActiveRecord::Migration[7.1]
  def change
    # 継続目標（このメニューを◯日継続する）が対象にする練習メニュー。
    # metric_key = 'menu_practice_days' のときのみ使う。
    add_reference :goals, :practice_menu, null: true, foreign_key: true
  end
end
