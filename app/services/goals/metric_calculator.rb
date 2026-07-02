module Goals
  # 目標の指標を、その目標の対象期間で集計して現在値を返す。
  # MVP対応 metric: practice_days / total_swing_count / game_count / batting_average / ops / era。
  class MetricCalculator
    def initialize(goal)
      @goal = goal
      @user = goal.user
    end

    # @return [Numeric] 期間内の現在値。期間が無ければ 0。
    def current_value
      range = @goal.period_range
      return 0 unless range

      from, to = range
      case @goal.metric_key
      when 'practice_days' then practice_days(from, to)
      when 'total_swing_count' then total_swing_count(from, to)
      when 'game_count' then game_count(from, to)
      when 'batting_average' then batting_average(from, to)
      when 'ops' then ops(from, to)
      when 'era' then era(from, to)
      else 0
      end
    end

    private

    # 大会目標のときは、対象期間内でも対象大会の試合だけに絞る（成績系 metric）。
    def tournament_filter
      @goal.period_type == 'tournament' ? @goal.tournament_id : nil
    end

    def practice_days(from, to)
      @user.activity_logs.where(activity_date: from.to_date..to.to_date)
           .where('intensity_level >= 1').count
    end

    def total_swing_count(from, to)
      @user.practice_logs.where(source: 'shadow_swing', logged_on: from.to_date..to.to_date).sum(:amount).to_i
    end

    def game_count(from, to)
      scope = MatchResult.joins(:game_result)
                         .where(game_results: { user_id: @user.id }, date_and_time: from..to)
      scope = scope.where(tournament_id: tournament_filter) if tournament_filter
      scope.count
    end

    def batting_scope(from, to)
      scope = BattingAverage.joins(game_result: :match_result)
                            .where(game_results: { user_id: @user.id })
                            .where(match_results: { date_and_time: from..to })
      scope = scope.where(match_results: { tournament_id: tournament_filter }) if tournament_filter
      scope
    end

    def batting_average(from, to)
      scope = batting_scope(from, to)
      at_bats = scope.sum(:at_bats)
      return 0 if at_bats.zero?

      (total_hits(scope).to_f / at_bats).round(3)
    end

    def ops(from, to)
      scope = batting_scope(from, to)
      at_bats = scope.sum(:at_bats)
      bb = scope.sum(:base_on_balls)
      hbp = scope.sum(:hit_by_pitch)
      sf = scope.sum(:sacrifice_fly)
      obp_denom = at_bats + bb + hbp + sf
      obp = obp_denom.zero? ? 0 : (total_hits(scope) + bb + hbp).to_f / obp_denom
      slg = at_bats.zero? ? 0 : scope.sum(:total_bases).to_f / at_bats
      (obp + slg).round(3)
    end

    def era(from, to)
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(game_results: { user_id: @user.id })
                            .where(match_results: { date_and_time: from..to })
      scope = scope.where(match_results: { tournament_id: tournament_filter }) if tournament_filter
      innings = scope.sum(:innings_pitched)
      return 0 if innings.zero?

      (scope.sum(:earned_run) * 9.0 / innings).round(2)
    end

    def total_hits(scope)
      scope.sum(Arel.sql('hit + two_base_hit + three_base_hit + home_run'))
    end
  end
end
