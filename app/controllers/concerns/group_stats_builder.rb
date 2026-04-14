module GroupStatsBuilder
  extend ActiveSupport::Concern

  private

  def build_group_stats(accepted_users)
    year = params[:year]
    match_type = params[:match_type]
    tournament_id = params[:tournament_id]

    batting_averages = accepted_users.map { |u| BattingAverage.filtered_aggregate_for_user(u.id, year:, match_type:, tournament_id:) }
    batting_stats = accepted_users.map { |u| BattingAverage.stats_for_user(u.id, year:, match_type:, tournament_id:) }
    pitching_aggregate = accepted_users.map do |u|
      PitchingResult.filtered_pitching_aggregate_for_user(u.id, year:, match_type:, tournament_id:)
    end
    pitching_stats = accepted_users.map { |u| PitchingResult.pitching_stats_for_user(u.id, year:, match_type:, tournament_id:) }
    available_years = fetch_available_years(accepted_users)
    available_tournaments = fetch_available_tournaments(accepted_users)

    { batting_averages:, batting_stats:, pitching_aggregate:, pitching_stats:, available_years:, available_tournaments: }
  end

  def fetch_available_years(accepted_users)
    user_ids = accepted_users.map(&:id)
    MatchResult.joins(:game_result)
               .where(game_results: { user_id: user_ids })
               .select('EXTRACT(YEAR FROM date_and_time) AS year')
               .distinct.order(Arel.sql('year DESC'))
               .map { |r| r.year.to_i }
  end

  def fetch_available_tournaments(accepted_users)
    user_ids = accepted_users.map(&:id)
    Tournament.joins(:match_results)
              .where(match_results: { user_id: user_ids })
              .distinct
              .order(:name)
  end
end
