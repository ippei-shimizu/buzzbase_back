module V2
  class GoalBadgeSerializer < ActiveModel::Serializer
    attributes :id, :badge_type, :badge_name, :awarded_at, :goal_id, :goal_title

    def goal_title
      object.goal.title
    end
  end
end
