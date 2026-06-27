module V2
  class ConditionLogSerializer < ActiveModel::Serializer
    attributes :id, :logged_on, :fatigue_level, :physical_level, :sleep_hours, :mood, :memo, :injuries
  end
end
