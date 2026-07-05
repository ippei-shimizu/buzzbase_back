module Goals
  # 目標の進捗率（0〜100）と達成判定を返す。
  # comparison_type が less_than（防御率など低いほど良い指標）の場合は比率を反転する。
  class ProgressCalculator
    def initialize(goal)
      @goal = goal
    end

    def current_value
      # 自由指標はユーザーが手入力した現在値、定性目標は数値を持たない。
      return @goal.manual_current_value.to_f if @goal.manual?
      return 0 if @goal.qualitative?

      @current_value ||= MetricCalculator.new(@goal).current_value
    end

    def progress_percent
      # 定性目標は達成/未達の2値。達成なら 100、未達なら 0。
      return @goal.is_achieved ? 100.0 : 0.0 if @goal.qualitative?

      target = @goal.target_value.to_f
      return 0 if target.zero?

      percent =
        if @goal.comparison_type == 'less_than'
          current_value.to_f.zero? ? 0 : target / current_value.to_f * 100
        else
          current_value.to_f / target * 100
        end
      percent.clamp(0, 100).round(1)
    end

    def achieved?
      # 定性目標はユーザーが手動で立てた達成フラグをそのまま使う。
      return @goal.is_achieved if @goal.qualitative?

      if @goal.comparison_type == 'less_than'
        current_value.to_f.positive? && current_value <= @goal.target_value
      else
        current_value >= @goal.target_value
      end
    end
  end
end
