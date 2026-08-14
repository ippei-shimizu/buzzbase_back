module V2
  class GoalBadgeSerializer < ActiveModel::Serializer
    # goal_title は付与時のスナップショット。元の目標が削除されても表示できる。
    attributes :id, :badge_type, :badge_name, :awarded_at, :goal_id, :goal_title
  end
end
