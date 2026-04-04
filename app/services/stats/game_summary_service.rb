# frozen_string_literal: true

module Stats
  class GameSummaryService
    MATCH_TYPES = %w[公式戦 オープン戦].freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
    end

    def call
      {
        win_loss: win_loss_summary,
        scoring:,
        recent_form:,
        monthly_games:,
        opponent_records:
      }
    end

    private

    def base_scope
      scope = GameResult.joins(:match_result)
                        .where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      apply_season_filter(scope)
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time <= ?',
                  "#{yr}-01-01 00:00:00", "#{yr}-12-31 23:59:59")
    end

    def apply_match_type_filter(scope)
      return scope if @match_type.blank? || @match_type == '全て'

      scope.where(match_results: { match_type: @match_type })
    end

    def apply_season_filter(scope)
      return scope if @season_id.blank?

      scope.where(game_results: { season_id: @season_id })
    end

    # --- win/loss summary ---
    def win_loss_summary
      results = base_scope
                .pluck(Arel.sql('match_results.my_team_score'), Arel.sql('match_results.opponent_team_score'))

      wins = 0
      losses = 0
      draws = 0

      results.each do |my_score, opp_score|
        if my_score > opp_score
          wins += 1
        elsif my_score < opp_score
          losses += 1
        else
          draws += 1
        end
      end

      total = wins + losses + draws
      win_rate = total.zero? ? 0.0 : (wins.to_f / total).round(3)

      { wins:, losses:, draws:, total:, win_rate: }
    end

    # --- scoring ---
    def scoring
      results = base_scope
                .pluck(Arel.sql('match_results.my_team_score'), Arel.sql('match_results.opponent_team_score'))

      runs_for = results.sum { |my, _| my.to_i }
      runs_against = results.sum { |_, opp| opp.to_i }
      total = results.size

      {
        runs_for:,
        runs_against:,
        run_differential: runs_for - runs_against,
        avg_runs_for: total.zero? ? 0.0 : (runs_for.to_f / total).round(1),
        avg_runs_against: total.zero? ? 0.0 : (runs_against.to_f / total).round(1)
      }
    end

    # --- recent form (last 5 games) ---
    def recent_form
      games = base_scope
              .joins('INNER JOIN teams ON teams.id = match_results.opponent_team_id')
              .select(Arel.sql(
                        'game_results.id AS game_result_id, ' \
                        'match_results.date_and_time, ' \
                        'teams.name AS opponent_name, ' \
                        'match_results.my_team_score, ' \
                        'match_results.opponent_team_score'
                      ))
              .order(Arel.sql('match_results.date_and_time DESC'))
              .limit(5)

      games.map do |g|
        my = g.my_team_score.to_i
        opp = g.opponent_team_score.to_i
        result = if my > opp then 'win'
                 elsif my < opp then 'loss'
                 else
                   'draw'
                 end
        {
          game_result_id: g.game_result_id,
          date: g.date_and_time.strftime('%m/%d'),
          opponent: g.opponent_name,
          result:,
          my_score: my,
          opponent_score: opp
        }
      end
    end

    # --- monthly games ---
    def monthly_games
      base_scope
        .select(Arel.sql('EXTRACT(MONTH FROM match_results.date_and_time)::int AS month, COUNT(*) AS count'))
        .group(Arel.sql('EXTRACT(MONTH FROM match_results.date_and_time)::int'))
        .order(Arel.sql('month'))
        .map { |r| { month: r.month, count: r.count } }
    end

    # --- opponent records ---
    def opponent_records
      results = base_scope
                .joins('INNER JOIN teams ON teams.id = match_results.opponent_team_id')
                .select(Arel.sql(
                          'teams.name AS team_name, ' \
                          'match_results.my_team_score, ' \
                          'match_results.opponent_team_score'
                        ))

      records = aggregate_opponent_results(results)

      sorted_records = records.map do |team_name, rec|
        total = rec[:wins] + rec[:losses] + rec[:draws]
        {
          team_name:,
          wins: rec[:wins], losses: rec[:losses], draws: rec[:draws],
          total:
        }
      end
      sorted_records.sort_by { |r| -r[:total] }
    end

    def aggregate_opponent_results(results)
      records = Hash.new { |h, k| h[k] = { wins: 0, losses: 0, draws: 0 } }

      results.each do |r|
        rec = records[r.team_name]
        if r.my_team_score > r.opponent_team_score
          rec[:wins] += 1
        elsif r.my_team_score < r.opponent_team_score
          rec[:losses] += 1
        else
          rec[:draws] += 1
        end
      end

      records
    end
  end
end
