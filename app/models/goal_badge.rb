class GoalBadge < ApplicationRecord
  belongs_to :user
  # 元の目標が削除されてもバッジは残す。goal は削除後 nil になる。
  belongs_to :goal, optional: true

  validates :goal_title, presence: true
end
