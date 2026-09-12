module V2
  class ActivityLogSerializer < ActiveModel::Serializer
    attributes :activity_date, :intensity_level, :has_game, :total_swing_count, :practice_menu_count
  end
end
