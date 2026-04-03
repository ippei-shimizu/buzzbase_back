# frozen_string_literal: true

module Stats
  class GameSummaryService
    MATCH_TYPES = %w[公式戦 オープン戦].freeze

    def initialize(user_id:, year: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @season_id = season_id
    end

    def call
      {
        win_loss: win_loss_summary,
        match_type_breakdown: match_type_breakdown,
        monthly_games: monthly_games,
        opponent_records: opponent_records
      }
    end

    private

    def base_scope
      scope = GameResult.joins(:match_result)
                        .where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_season_filter(scope)
      scope
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      scope.where(match_results: {
                    date_and_time: Date.new(@year.to_i, 1, 1)..Date.new(@year.to_i, 12, 31)
                  })
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

      { wins: wins, losses: losses, draws: draws, total: total, win_rate: win_rate }
    end

    # --- match type breakdown ---
    def match_type_breakdown
      MATCH_TYPES.map do |mt|
        scope = base_scope.where(match_results: { match_type: mt })
        results = scope.pluck(Arel.sql('match_results.my_team_score'),
                              Arel.sql('match_results.opponent_team_score'))

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

        {
          match_type: mt, total: total,
          wins: wins, losses: losses, draws: draws,
          win_rate: win_rate
        }
      end
    end

    # --- monthly games ---
    def monthly_games
      base_scope
        .select(Arel.sql("EXTRACT(MONTH FROM match_results.date_and_time)::int AS month, COUNT(*) AS count"))
        .group(Arel.sql("EXTRACT(MONTH FROM match_results.date_and_time)::int"))
        .order(Arel.sql("month"))
        .map { |r| { month: r.month, count: r.count } }
    end

    # --- opponent records ---
    def opponent_records
      results = base_scope
                .joins('INNER JOIN teams ON teams.id = match_results.opponent_team_id')
                .select(Arel.sql(
                          "teams.name AS team_name, " \
                          "match_results.my_team_score, " \
                          "match_results.opponent_team_score"
                        ))

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

      records.map do |team_name, rec|
        total = rec[:wins] + rec[:losses] + rec[:draws]
        {
          team_name: team_name,
          wins: rec[:wins], losses: rec[:losses], draws: rec[:draws],
          total: total
        }
      end.sort_by { |r| -r[:total] }
    end
  end
end
