module Goals
  # 目標の指標を、その目標の対象期間で集計して現在値を返す。
  # 対応 metric は DISPATCH（Goal::METRIC_KEYS と対応）。自動集計できる打撃/投手/練習の値。
  class MetricCalculator # rubocop:disable Metrics/ClassLength
    # metric_key → 集計メソッド。Goal::METRIC_KEYS で検証済みの許可リスト。
    DISPATCH = {
      'practice_days' => :practice_days,
      'self_practice_days' => :self_practice_days,
      'total_swing_count' => :total_swing_count,
      'game_count' => :game_count,
      'menu_practice_days' => :menu_practice_days,
      'menu_practice_amount' => :menu_practice_amount,
      'batting_average' => :batting_average,
      'on_base_percentage' => :on_base_percentage,
      'slugging_percentage' => :slugging_percentage,
      'ops' => :ops,
      'hits' => :hits,
      'home_runs' => :home_runs,
      'runs_batted_in' => :runs_batted_in,
      'runs_scored' => :runs_scored,
      'stolen_bases' => :stolen_bases,
      'era' => :era,
      'whip' => :whip,
      'strikeouts' => :strikeouts,
      'wins' => :wins,
      'saves' => :saves
    }.freeze

    def initialize(goal)
      @goal = goal
      @user = goal.user
    end

    # @return [Numeric, nil] 期間内の現在値。
    #   era / whip は「登板なし」を nil で返し、真の 0.00（完全投球）と区別する。
    def current_value
      range = @goal.period_range
      return no_data_value unless range

      method = DISPATCH[@goal.metric_key]
      method ? send(method, *range) : 0
    end

    private

    # 期間が確定しない（例: 試合が1つもないシーズン目標）ときの値。
    # era / whip はデータなしを nil で表し、それ以外の加算系指標は 0 とする。
    def no_data_value
      %w[era whip].include?(@goal.metric_key) ? nil : 0
    end

    def hits(from, to)
      total_hits(batting_scope(from, to)).to_i
    end

    def home_runs(from, to)
      batting_scope(from, to).sum(:home_run)
    end

    def runs_batted_in(from, to)
      batting_scope(from, to).sum(:runs_batted_in)
    end

    def runs_scored(from, to)
      batting_scope(from, to).sum(:run)
    end

    def stolen_bases(from, to)
      batting_scope(from, to).sum(:stealing_base)
    end

    def strikeouts(from, to)
      pitching_scope(from, to).sum(:strikeouts)
    end

    def wins(from, to)
      pitching_scope(from, to).sum(:win)
    end

    def saves(from, to)
      pitching_scope(from, to).sum(:saves)
    end

    # 大会目標のときは、対象期間内でも対象大会の試合だけに絞る（成績系 metric）。
    def tournament_filter
      @goal.period_type == 'tournament' ? @goal.tournament_id : nil
    end

    # シーズン目標のときは、period_range（対象シーズンの試合の最小〜最大日時）だけでは
    # 同期間の他シーズン/無所属の試合まで拾ってしまうため、season_id でも絞り込む。
    def season_filter
      @goal.period_type == 'season' ? @goal.season_id : nil
    end

    def practice_days(from, to)
      @user.activity_logs.where(activity_date: from.to_date..to.to_date)
           .where('intensity_level >= 1').count
    end

    # 自主練習として記録した日のうち、実際に練習ログがある日を数える。
    def self_practice_days(from, to)
      @user.practice_sessions
           .where(practice_type: 'self_practice', logged_on: from.to_date..to.to_date)
           .joins(:practice_logs)
           .distinct.count
    end

    # 新規作成は不可（Goal::DEPRECATED_METRIC_KEYS）。既存目標の集計のためだけに残す。
    def total_swing_count(from, to)
      @user.practice_logs.where(source: 'shadow_swing', logged_on: from.to_date..to.to_date).sum(:amount).to_i
    end

    # 継続目標: 対象メニューを期間内で実施した「日数」（同日複数回は1日）。
    def menu_practice_days(from, to)
      return 0 if @goal.practice_menu_id.nil?

      @user.practice_logs
           .where(practice_menu_id: @goal.practice_menu_id, logged_on: from.to_date..to.to_date)
           .distinct.count(:logged_on)
    end

    # メニュー回数: 対象メニューの実施量を期間内で合計する。単位はそのメニューの unit_label。
    # 素振りメニューを選んだ場合は素振り自動ログ（source=shadow_swing）も対象に含む。
    def menu_practice_amount(from, to)
      return 0 if @goal.practice_menu_id.nil?

      @user.practice_logs
           .where(practice_menu_id: @goal.practice_menu_id, logged_on: from.to_date..to.to_date)
           .sum(:amount).to_f.round(2)
    end

    def game_count(from, to)
      scope = MatchResult.joins(:game_result)
                         .where(game_results: { user_id: @user.id }, date_and_time: from..to)
      scope = scope.where(tournament_id: tournament_filter) if tournament_filter
      scope = scope.where(game_results: { season_id: season_filter }) if season_filter
      scope.count
    end

    def batting_scope(from, to)
      scope = BattingAverage.joins(game_result: :match_result)
                            .where(game_results: { user_id: @user.id })
                            .where(match_results: { date_and_time: from..to })
      scope = scope.where(match_results: { tournament_id: tournament_filter }) if tournament_filter
      scope = scope.where(game_results: { season_id: season_filter }) if season_filter
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

    def on_base_percentage(from, to)
      scope = batting_scope(from, to)
      at_bats = scope.sum(:at_bats)
      bb = scope.sum(:base_on_balls)
      hbp = scope.sum(:hit_by_pitch)
      denom = at_bats + bb + hbp + scope.sum(:sacrifice_fly)
      return 0 if denom.zero?

      ((total_hits(scope) + bb + hbp).to_f / denom).round(3)
    end

    def slugging_percentage(from, to)
      scope = batting_scope(from, to)
      at_bats = scope.sum(:at_bats)
      return 0 if at_bats.zero?

      (scope.sum(:total_bases).to_f / at_bats).round(3)
    end

    def pitching_scope(from, to)
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(game_results: { user_id: @user.id })
                            .where(match_results: { date_and_time: from..to })
      scope = scope.where(match_results: { tournament_id: tournament_filter }) if tournament_filter
      scope = scope.where(game_results: { season_id: season_filter }) if season_filter
      scope
    end

    # inning_format（7 or 9）で earned_run を加重してから投球回で割る。
    # Stats::EraTrendService / PeriodicReviews::Generator と同じ計算方式に揃える。
    def era(from, to)
      scope = pitching_scope(from, to)
      innings = scope.sum(:innings_pitched)
      return nil if innings.zero?

      weighted_earned = scope.sum(Arel.sql('earned_run * match_results.inning_format'))
      (weighted_earned / innings).round(2)
    end

    def whip(from, to)
      scope = pitching_scope(from, to)
      innings = scope.sum(:innings_pitched)
      return nil if innings.zero?

      ((scope.sum(:base_on_balls) + scope.sum(:hits_allowed)).to_f / innings).round(2)
    end

    def total_hits(scope)
      scope.sum(Arel.sql('hit + two_base_hit + three_base_hit + home_run'))
    end
  end
end
