# frozen_string_literal: true

module Stats
  class EraTrendService
    INNINGS_PER_GAME = 9

    def initialize(user_id:, year: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @season_id = season_id
    end

    def call
      scope = base_scope
      return [] if scope.none?

      # 月ごとに集計
      monthly = scope
                .select(Arel.sql(
                          'EXTRACT(MONTH FROM match_results.date_and_time)::int AS month, ' \
                          'SUM(pitching_results.innings_pitched) AS total_ip, ' \
                          'SUM(pitching_results.earned_run) AS total_er'
                        ))
                .group(Arel.sql('EXTRACT(MONTH FROM match_results.date_and_time)::int'))
                .order(Arel.sql('month'))

      monthly.filter_map do |r|
        ip = r.total_ip.to_f
        next if ip <= 0

        era = (r.total_er.to_f / ip * INNINGS_PER_GAME).round(2)
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
        scope = scope.where('match_results.date_and_time >= ? AND match_results.date_and_time <= ?',
                            "#{yr}-01-01 00:00:00", "#{yr}-12-31 23:59:59")
      end

      scope = scope.where(game_results: { season_id: @season_id }) if @season_id.present?
      scope
    end
  end
end
