# frozen_string_literal: true

module Stats
  class EraTrendService
    def initialize(user_id:, year: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # 月別の防御率推移を返す。
    # ERA は `SUM(earned_run × match_results.inning_format) / SUM(innings_pitched)` で算出し、
    # 7回制／9回制が混在しても各試合のイニング制を加重した値で計算する。
    # @return [Array<Hash{Symbol=>Numeric}>] [{ month: Integer, era: Float }, ...]
    def call
      scope = base_scope
      return [] if scope.none?

      # 月ごとに集計（earned_run には inning_format を係数として掛けて加重する）
      monthly = scope
                .select(Arel.sql(
                          "#{Stats::JstDateSql::MONTH_JST_INT_SQL} AS month, " \
                          'SUM(pitching_results.innings_pitched) AS total_ip, ' \
                          'SUM(pitching_results.earned_run * match_results.inning_format) AS total_weighted_er'
                        ))
                .group(Arel.sql(Stats::JstDateSql::MONTH_JST_INT_SQL))
                .order(Arel.sql('month'))

      monthly.filter_map do |r|
        ip = r.total_ip.to_f
        next if ip <= 0

        era = (r.total_weighted_er.to_f / ip).round(2)
        { month: r.month, era: }
      end
    end

    private

    def base_scope
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(pitching_results: { user_id: @user_id })
                            .where('pitching_results.innings_pitched > 0')

      if @year.present? && @year.to_s != '通算'
        yr = @year.to_i
        range_start = Time.zone.local(yr, 1, 1)
        range_end = Time.zone.local(yr + 1, 1, 1)
        scope = scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                            range_start, range_end)
      end

      scope = scope.where(game_results: { season_id: @season_id }) if @season_id.present?
      scope = scope.where(match_results: { tournament_id: @tournament_id }) if @tournament_id.present?
      scope
    end
  end
end
