class PreserveGoalBadgesOnGoalDeletion < ActiveRecord::Migration[7.1]
  # バッジは「達成の記念」として恒久保存する想定だが、元の目標を削除すると
  # dependent: :destroy で一緒に消えていた。goal_id を nullify できるようにし、
  # 目標が消えても一覧に出せるよう表示名をスナップショットする。
  def up
    add_column :goal_badges, :goal_title, :string
    execute <<~SQL.squish
      UPDATE goal_badges
      SET goal_title = goals.title
      FROM goals
      WHERE goal_badges.goal_id = goals.id
    SQL
    change_column_null :goal_badges, :goal_title, false
    change_column_null :goal_badges, :goal_id, true
  end

  def down
    change_column_null :goal_badges, :goal_id, false
    remove_column :goal_badges, :goal_title
  end
end
