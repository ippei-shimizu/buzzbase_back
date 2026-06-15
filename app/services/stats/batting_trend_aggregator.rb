# frozen_string_literal: true

module Stats
  # 打撃成績の推移グラフ用 Aggregator。
  #
  # batting_averages テーブルを試合単位 (granularity=game) もしくは
  # 月単位 (granularity=month) で時系列集計し、各時点の打率 / OBP / SLG / OPS を返す。
  # OBP/SLG/OPS の計算式は HeadlineStatsAggregator と同一に揃え、フロント側で
  # 同じ計算を持つことによる端数ズレを防ぐ。
  #
  # granularity=game は **累積** を返す（最初の試合から各時点までの通算成績）。
  # granularity=month は **その月単独** を返す（各月でリセット）。
  class BattingTrendAggregator
    SUM_COLUMNS = %i[at_bats hit total_bases base_on_balls hit_by_pitch sacrifice_fly].freeze

    def initialize(user_id:, granularity: 'game', # rubocop:disable Metrics/ParameterLists
                   year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @granularity = granularity.to_s == 'month' ? 'month' : 'game'
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] granularity と points 配列。
    #   points の各要素は key / label / batting_average / on_base_percentage /
    #   slugging_percentage / ops / at_bats_in_period / cumulative_at_bats を持つ。
    def call
      points = @granularity == 'month' ? aggregate_by_month : aggregate_by_game
      { granularity: @granularity, points: }
    end

    private

    # 各試合の SUM 列をまとめて取得 → 累積で打率等を計算。
    def aggregate_by_game
      rows = aggregate_per_game_rows
      cumulative = SUM_COLUMNS.index_with { 0 }
      rows.map do |row|
        SUM_COLUMNS.each { |col| cumulative[col] += row[col] }
        build_point(
          key: row[:date].to_date.iso8601,
          label: row[:date].strftime('%-m/%-d'),
          period_stats: row,
          cumulative_stats: cumulative
        )
      end
    end

    # 月ごとの SUM をそのまま使い、月単独の打率等を返す（cumulative も月単独に合わせる）。
    def aggregate_by_month
      aggregate_per_month_rows.map do |row|
        build_point(
          key: row[:key],
          label: "#{row[:month]}月",
          period_stats: row,
          cumulative_stats: row
        )
      end
    end

    def aggregate_per_game_rows
      # game_result_id 単位で SUM。同じ試合に複数 batting_averages が並ぶ場合に備えて
      # game_result_id でグループしておく。並びは match_results.date_and_time の昇順。
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      rows = filtered_scope
             .group('game_results.id, match_results.date_and_time')
             .order(Arel.sql('match_results.date_and_time ASC'))
             .pluck(Arel.sql("match_results.date_and_time, #{sum_sql}"))

      rows.map do |row|
        date, *values = row
        { date: }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def aggregate_per_month_rows
      year_sql = 'EXTRACT(YEAR FROM match_results.date_and_time)::int'
      month_sql = 'EXTRACT(MONTH FROM match_results.date_and_time)::int'
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      rows = filtered_scope
             .group(Arel.sql("#{year_sql}, #{month_sql}"))
             .order(Arel.sql("#{year_sql} ASC, #{month_sql} ASC"))
             .pluck(Arel.sql("#{year_sql}, #{month_sql}, #{sum_sql}"))

      rows.map do |row|
        year, month, *values = row
        {
          key: format('%<year>04d-%<month>02d', year: year.to_i, month: month.to_i),
          month: month.to_i,
          year: year.to_i
        }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def build_point(key:, label:, period_stats:, cumulative_stats:)
      at_bats = cumulative_stats[:at_bats]
      obp_denom = at_bats + cumulative_stats[:base_on_balls] +
                  cumulative_stats[:hit_by_pitch] + cumulative_stats[:sacrifice_fly]
      obp_num = cumulative_stats[:hit] + cumulative_stats[:base_on_balls] +
                cumulative_stats[:hit_by_pitch]
      obp = safe_divide(obp_num, obp_denom)
      slg = safe_divide(cumulative_stats[:total_bases], at_bats)

      {
        key:,
        label:,
        batting_average: safe_divide(cumulative_stats[:hit], at_bats),
        on_base_percentage: obp,
        slugging_percentage: slg,
        ops: round3(obp + slg),
        at_bats_in_period: period_stats[:at_bats].to_i,
        cumulative_at_bats: at_bats
      }
    end

    def filtered_scope
      @filtered_scope ||= begin
        scope = BattingAverage.joins(game_result: :match_result).where(user_id: @user_id)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                  "#{yr}-01-01 00:00:00", "#{yr + 1}-01-01 00:00:00")
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
