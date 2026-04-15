module Groups
  class StatsBuilder
    def initialize(accepted_users:, year: nil, match_type: nil, tournament_id: nil)
      @accepted_users = accepted_users
      @year = year
      @match_type = match_type
      @tournament_id = tournament_id
    end

    def call
      {
        batting_averages:,
        batting_stats:,
        pitching_aggregate:,
        pitching_stats:,
        available_years:,
        available_tournaments:
      }
    end

    private

    attr_reader :accepted_users, :year, :match_type, :tournament_id

    def batting_averages
      accepted_users.map { |u| BattingAverage.filtered_aggregate_for_user(u.id, year:, match_type:, tournament_id:) }
    end

    def batting_stats
      accepted_users.map { |u| BattingAverage.stats_for_user(u.id, year:, match_type:, tournament_id:) }
    end

    def pitching_aggregate
      accepted_users.map { |u| PitchingResult.filtered_pitching_aggregate_for_user(u.id, year:, match_type:, tournament_id:) }
    end

    def pitching_stats
      accepted_users.map { |u| PitchingResult.pitching_stats_for_user(u.id, year:, match_type:, tournament_id:) }
    end

    def available_years
      MatchResult.where(user_id: user_ids)
                 .select('EXTRACT(YEAR FROM date_and_time) AS year')
                 .distinct.order(Arel.sql('year DESC'))
                 .map { |r| r.year.to_i }
    end

    def available_tournaments
      Tournament.joins(:match_results)
                .where(match_results: { user_id: user_ids })
                .distinct
                .order(:name)
    end

    def user_ids
      @user_ids ||= accepted_users.map(&:id)
    end
  end
end
