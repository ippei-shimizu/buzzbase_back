module V2
  class GoalSerializer < ActiveModel::Serializer
    attributes :id, :title, :kind, :period_type, :season_id, :tournament_id, :month_start, :deadline,
               :metric_key, :target_value, :comparison_type, :practice_menu_id, :practice_menu_name,
               :practice_menu_unit_label,
               :custom_metric_label, :custom_unit, :manual_current_value,
               :is_achieved, :is_finalized, :achieved_value,
               :current_value, :progress_percent, :days_remaining

    delegate :progress_percent, to: :progress

    # era / whip の「登板なし」は内部的に nil だが、クライアント互換のため 0 で返す
    # （達成判定・進捗率は計算側で nil を考慮済み）。
    def current_value
      progress.current_value.to_f
    end

    def practice_menu_name
      object.practice_menu&.name
    end

    # menu_practice_amount の単位はメニューごとに変わるため、指標固定の単位では表せない。
    def practice_menu_unit_label
      object.practice_menu&.unit_label
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
