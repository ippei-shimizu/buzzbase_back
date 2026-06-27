module V2
  class GoalSerializer < ActiveModel::Serializer
    attributes :id, :title, :period_type, :season_id, :month_start, :deadline,
               :metric_key, :target_value, :comparison_type,
               :is_achieved, :is_finalized, :achieved_value,
               :current_value, :progress_percent, :days_remaining

    delegate :current_value, to: :progress

    delegate :progress_percent, to: :progress

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
