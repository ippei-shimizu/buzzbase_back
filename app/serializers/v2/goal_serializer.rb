module V2
  class GoalSerializer < ActiveModel::Serializer
    attributes :id, :title, :kind, :period_type, :season_id, :tournament_id, :month_start, :deadline,
               :metric_key, :target_value, :comparison_type, :practice_menu_id, :practice_menu_name,
               :custom_metric_label, :custom_unit, :manual_current_value,
               :is_achieved, :is_finalized, :achieved_value,
               :current_value, :progress_percent, :days_remaining

    delegate :current_value, to: :progress

    delegate :progress_percent, to: :progress

    def practice_menu_name
      object.practice_menu&.name
    end

    def days_remaining
      return 0 if object.deadline.nil?

      [(object.deadline - Time.find_zone('Asia/Tokyo').today).to_i, 0].max
    end

    private

    def progress
      @progress ||= ::Goals::ProgressCalculator.new(object)
    end
  end
end
