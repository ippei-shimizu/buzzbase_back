# frozen_string_literal: true

module Stats
  # 防御率推移グラフ用 Service。
  # 月単位 (granularity=month、デフォルト) もしくはシーズン単位 (granularity=season) で
  # 時系列集計し、各時点のERAを返す。ERA は
  # `SUM(earned_run × match_results.inning_format) / SUM(innings_pitched)` で算出し、
  # 7回制／9回制が混在しても各試合のイニング制を加重した値で計算する。
  class EraTrendService
    SUPPORTED_GRANULARITIES = %w[month season].freeze

    def initialize(user_id:, granularity: 'month',
                   year: nil, season_id: nil, tournament_id: nil, start_month: nil, end_month: nil)
      @user_id = user_id
      @granularity = SUPPORTED_GRANULARITIES.include?(granularity.to_s) ? granularity.to_s : 'month'
      @year = year
      @season_id = season_id
      @tournament_id = tournament_id
      @start_month = start_month
      @end_month = end_month
    end

    # @return [Hash] granularity と points 配列。points は key / label / era を持つ。
    def call
      points = @granularity == 'season' ? aggregate_by_season : aggregate_by_month
      { granularity: @granularity, points: }
    end

    private

    def aggregate_by_month
      scope = base_scope
      return [] if scope.none?

      rows = scope
             .select(Arel.sql(
                       "#{Stats::JstDateSql::MONTH_JST_INT_SQL} AS month, " \
                       'SUM(pitching_results.innings_pitched) AS total_ip, ' \
                       'SUM(pitching_results.earned_run * match_results.inning_format) AS total_weighted_er'
                     ))
             .group(Arel.sql(Stats::JstDateSql::MONTH_JST_INT_SQL))
             .order(Arel.sql('month'))

      rows.filter_map do |r|
        era = era_for(total_ip: r.total_ip, total_weighted_er: r.total_weighted_er)
        next if era.nil?

        { key: format('month-%<month>02d', month: r.month.to_i), label: "#{r.month}月", era: }
      end
    end

    # シーズンごとのERAを返す（シーズン跨ぎ比較）。season_id が未割り当ての試合は集計対象外。
    def aggregate_by_season
      scope = base_scope
      return [] if scope.none?

      rows = scope
             .joins('INNER JOIN seasons ON seasons.id = game_results.season_id')
             .select(Arel.sql(
                       'seasons.id AS season_id, seasons.name AS season_name, seasons.created_at AS season_created_at, ' \
                       'SUM(pitching_results.innings_pitched) AS total_ip, ' \
                       'SUM(pitching_results.earned_run * match_results.inning_format) AS total_weighted_er'
                     ))
             .group('seasons.id, seasons.name, seasons.created_at')
             .order(Arel.sql('seasons.created_at ASC'))

      rows.filter_map do |r|
        era = era_for(total_ip: r.total_ip, total_weighted_er: r.total_weighted_er)
        next if era.nil?

        { key: "season-#{r.season_id}", label: r.season_name, era: }
      end
    end

    def era_for(total_ip:, total_weighted_er:)
      ip = total_ip.to_f
      return nil if ip <= 0

      (total_weighted_er.to_f / ip).round(2)
    end

    def base_scope
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(pitching_results: { user_id: @user_id })
                            .where('pitching_results.innings_pitched > 0')

      if @year.present? && @year.to_s != '通算'
        year = @year.to_i
        range_start = Time.zone.local(year, 1, 1)
        range_end = Time.zone.local(year + 1, 1, 1)
        scope = scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                            range_start, range_end)
      end

      scope = scope.where(game_results: { season_id: @season_id }) if @season_id.present?
      scope = scope.where(match_results: { tournament_id: @tournament_id }) if @tournament_id.present?
      PeriodRange.apply(scope, @start_month, @end_month)
    end
  end
end
