# frozen_string_literal: true

module Stats
  # stats 投球タブの主要スタッツ / その他数値カード用に、投球成績の累計と率指標を返す Aggregator。
  #
  # 集計対象・計算式は PitchingStatsTableService の通算行に揃える（投球回 0 の試合は登板に数えない、
  # ERA / K/9 / BB/9 は試合ごとのイニング制で加重する）。フィルタは打撃の HeadlineStatsAggregator と同じ。
  class PitchingSummaryAggregator
    include Concerns::FilterableConcern

    COUNT_COLUMNS = {
      appearances: 'COUNT(*)',
      win: 'SUM(COALESCE(pitching_results.win, 0))',
      loss: 'SUM(COALESCE(pitching_results.loss, 0))',
      hold: 'SUM(COALESCE(pitching_results.hold, 0))',
      saves: 'SUM(COALESCE(pitching_results.saves, 0))',
      complete_games: 'SUM(CASE WHEN pitching_results.got_to_the_distance THEN 1 ELSE 0 END)',
      shutouts: 'SUM(CASE WHEN pitching_results.got_to_the_distance AND pitching_results.run_allowed = 0 THEN 1 ELSE 0 END)',
      number_of_pitches: 'SUM(COALESCE(pitching_results.number_of_pitches, 0))',
      hits_allowed: 'SUM(COALESCE(pitching_results.hits_allowed, 0))',
      home_runs_hit: 'SUM(COALESCE(pitching_results.home_runs_hit, 0))',
      strikeouts: 'SUM(COALESCE(pitching_results.strikeouts, 0))',
      base_on_balls: 'SUM(COALESCE(pitching_results.base_on_balls, 0))',
      hit_by_pitch: 'SUM(COALESCE(pitching_results.hit_by_pitch, 0))',
      run_allowed: 'SUM(COALESCE(pitching_results.run_allowed, 0))',
      earned_run: 'SUM(COALESCE(pitching_results.earned_run, 0))',
      weighted_earned_run: 'SUM(COALESCE(pitching_results.earned_run, 0) * match_results.inning_format)',
      weighted_strikeouts: 'SUM(COALESCE(pitching_results.strikeouts, 0) * match_results.inning_format)',
      weighted_base_on_balls: 'SUM(COALESCE(pitching_results.base_on_balls, 0) * match_results.inning_format)'
    }.freeze

    INNINGS_COLUMN = 'SUM(pitching_results.innings_pitched)'

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil, start_month: nil, end_month: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
      @start_month = start_month
      @end_month = end_month
    end

    # @return [Hash] 登板〜自責点の累計、投球回、ERA / WHIP / K/9 / BB/9 / K/BB / 勝率。
    #   登板 0 でも nil / NaN ではなく 0 / 0.0 を返す
    def call
      counts, innings = aggregate
      counts.except(:weighted_earned_run, :weighted_strikeouts, :weighted_base_on_balls)
            .merge(innings_pitched: innings.round(2))
            .merge(rates(counts, innings))
    end

    private

    # 投球回は 1/3 回を 0.333... の float で保存しているため、率の分母には丸める前の合計を使う。
    def aggregate
      columns = COUNT_COLUMNS.merge(innings_pitched: INNINGS_COLUMN)
      values = filtered_scope.pick(*columns.values.map { |sql| Arel.sql(sql) })
      row = columns.keys.zip(values).to_h
      [row.except(:innings_pitched).transform_values(&:to_i), row[:innings_pitched].to_f]
    end

    def rates(counts, innings)
      PitchingFormulas.rates(
        **counts.slice(:weighted_earned_run, :weighted_strikeouts, :weighted_base_on_balls,
                       :strikeouts, :base_on_balls, :hits_allowed, :win, :loss),
        innings:
      )
    end

    def filtered_scope
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(pitching_results: { user_id: @user_id })
                            .where('pitching_results.innings_pitched > 0')
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      scope = apply_season_filter(scope)
      scope = apply_tournament_filter(scope)
      apply_date_range_filter(scope)
    end
  end
end
