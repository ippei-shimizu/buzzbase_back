# frozen_string_literal: true

module Stats
  # stats 打撃の追加スタッツ（主要スタッツ以外）を返す Aggregator。
  #
  # HeadlineStatsAggregator が返す 8 指標（打率 / 安打 / 本塁打 / 打点 /
  # 出塁率 / 長打率 / OPS / 打数）以外の項目を 16 個まとめて返す。
  # マイページ / ダッシュボードの SummaryStatsTable と同じ項目を網羅する。
  #
  # フィルタは HeadlineStatsAggregator と同じ 5 項目（year / match_type /
  # season_id / tournament_id）を踏襲する。
  class AdditionalStatsAggregator
    SUM_COLUMNS = %i[
      plate_appearances at_bats hit total_bases
      two_base_hit three_base_hit
      run strike_out base_on_balls hit_by_pitch
      sacrifice_hit sacrifice_fly stealing_base caught_stealing
    ].freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] 16 指標 + 三振内訳 (swinging / looking)。
    #   母数 0 でも nil ではなく 0 / 0.0 を返す。
    def call
      stats = aggregate_stats
      raw_counts(stats)
        .merge(computed_rates(stats))
        .merge(games: count_games)
        .merge(aggregate_strike_out_breakdown)
    end

    private

    # plate_appearances.swing_type の内訳を新仕様 PA から直接集計する。
    # batting_averages 側にカラムを増やすと recalculator 連鎖の影響が広いため、
    # 追加クエリ 2 本で済ませる。旧 PA (is_new_format=false) と
    # 振り逃げ (plate_result_id=14) は対象外で、新仕様の純粋な三振 (id=13)
    # のうち swing_type 別のカウントを返す。
    def aggregate_strike_out_breakdown
      strikeouts = filtered_pa_scope.where(plate_result_id: PlateAppearance::STRIKEOUT_RESULT_ID)
      {
        swinging_strike_out: strikeouts.swing_type_swinging.count,
        looking_strike_out: strikeouts.swing_type_looking.count
      }
    end

    def raw_counts(stats)
      {
        plate_appearances: stats[:plate_appearances],
        two_base_hit: stats[:two_base_hit],
        three_base_hit: stats[:three_base_hit],
        total_bases: stats[:total_bases],
        run: stats[:run],
        strike_out: stats[:strike_out],
        base_on_balls: stats[:base_on_balls],
        hit_by_pitch: stats[:hit_by_pitch],
        sacrifice_hit: stats[:sacrifice_hit],
        sacrifice_fly: stats[:sacrifice_fly],
        stealing_base: stats[:stealing_base],
        caught_stealing: stats[:caught_stealing]
      }
    end

    def computed_rates(stats)
      at_bats = stats[:at_bats]
      batting_average = safe_divide(stats[:hit], at_bats)
      obp_denom = at_bats + stats[:base_on_balls] + stats[:hit_by_pitch] + stats[:sacrifice_fly]
      obp = safe_divide(stats[:hit] + stats[:base_on_balls] + stats[:hit_by_pitch], obp_denom)
      slg = safe_divide(stats[:total_bases], at_bats)
      {
        iso: round3(slg - batting_average),
        isod: round3(obp - batting_average),
        bb_per_k: safe_divide(stats[:base_on_balls], stats[:strike_out])
      }
    end

    # HeadlineStatsAggregator と同じ pluck + SUM(COALESCE) パターン。
    def aggregate_stats
      row = filtered_scope.pick(*SUM_COLUMNS.map { |col| Arel.sql("SUM(COALESCE(#{col}, 0))") })
      values = Array.wrap(row).map(&:to_i)
      SUM_COLUMNS.zip(values).to_h
    end

    # 試合数は batting_averages の DISTINCT game_result_id でカウントする。
    def count_games
      filtered_scope.distinct.count(:game_result_id)
    end

    # call 内で aggregate_stats / count_games から 2 度参照されるため、
    # 他の Stats Aggregator と同じくメモ化してスコープ構築のコストを削る。
    def filtered_scope
      @filtered_scope ||= begin
        scope = BattingAverage.joins(game_result: :match_result).where(user_id: @user_id)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

    # swing_type 内訳は plate_appearances を直接集計する必要があるため、
    # batting_averages 経由の filtered_scope とは別系統の同フィルタを用意する。
    def filtered_pa_scope
      @filtered_pa_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      range_start = Time.zone.local(yr, 1, 1)
      range_end = Time.zone.local(yr + 1, 1, 1)
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                  range_start, range_end)
    end

    def apply_match_type_filter(scope)
      return scope if @match_type.blank? || @match_type == '全て'

      scope.where(match_results: { match_type: @match_type })
    end

    def apply_season_filter(scope)
      return scope if @season_id.blank?

      scope.where(game_results: { season_id: @season_id })
    end

    def apply_tournament_filter(scope)
      return scope if @tournament_id.blank?

      scope.where(match_results: { tournament_id: @tournament_id })
    end

    def safe_divide(numerator, denominator)
      return 0.0 if denominator.to_i.zero?

      round3(numerator.to_f / denominator)
    end

    def round3(value)
      value.round(3)
    end
  end
end
