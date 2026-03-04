class PitchingResult < ApplicationRecord
  belongs_to :game_result
  belongs_to :user

  INNINGS_PER_GAME = 9
  ZERO = 0

  def self.pitching_aggregate_for_user(user_id)
    pitching_aggregate_query.where(user_id:)
  end

  def self.pitching_aggregate_for_users(user_ids)
    pitching_aggregate_query.where(user_id: user_ids)
  end

  def self.pitching_aggregate_query
    select(*pitching_aggregate_columns).group('pitching_results.user_id')
  end

  def self.pitching_aggregate_columns
    ['pitching_results.user_id',
     'SUM(CASE WHEN innings_pitched > 0 THEN 1 ELSE 0 END) AS number_of_appearances',
     'SUM(win) AS win',
     'SUM(CASE WHEN got_to_the_distance THEN 1 ELSE 0 END) AS complete_games',
     "SUM(CASE WHEN got_to_the_distance = 't' AND run_allowed = 0 THEN 1 ELSE 0 END) AS shutouts",
     'SUM(loss) AS loss',
     'SUM(hold) AS hold',
     'SUM(saves) AS saves',
     'ROUND(SUM(innings_pitched)::numeric, 2) AS innings_pitched',
     'SUM(hits_allowed) AS hits_allowed',
     'SUM(home_runs_hit) AS home_runs_hit',
     'SUM(strikeouts) AS strikeouts',
     'SUM(base_on_balls) AS base_on_balls',
     'SUM(hit_by_pitch) AS hit_by_pitch',
     'SUM(run_allowed) AS run_allowed',
     'SUM(earned_run) AS earned_run']
  end

  def self.filtered_pitching_aggregate_for_user(user_id, year: nil, match_type: nil)
    scope = joins(game_result: :match_result).select(*pitching_aggregate_columns)
    scope = apply_filters(scope, year, match_type)
    scope.where(pitching_results: { user_id: }).group('pitching_results.user_id')
  end

  def self.pitching_stats_for_user(user_id, year: nil, match_type: nil)
    if year.present? || match_type.present?
      scope = apply_filters(joins(game_result: :match_result), year, match_type)
      result = scope.select(*pitching_aggregate_columns)
                    .where(pitching_results: { user_id: })
                    .group('pitching_results.user_id').take
    else
      result = pitching_aggregate_query.find_by(user_id:)
    end

    return nil unless result

    build_pitching_stats_hash(user_id, result.attributes)
  end

  def self.bulk_pitching_stats_for_users(user_ids)
    results = pitching_aggregate_query.where(user_id: user_ids)

    results.each_with_object({}) do |result, hash|
      hash[result.user_id] = build_pitching_stats_hash(result.user_id, result.attributes)
    end
  end

  # filtered_pitching_stats_for_user を pitching_stats_for_user に統合（後方互換エイリアス）
  class << self
    alias filtered_pitching_stats_for_user pitching_stats_for_user
  end

  def self.apply_filters(scope, year, match_type)
    scope = scope.where(match_results: { date_and_time: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31) }) if year.present? && year.to_s != '通算'
    scope = scope.where(match_results: { match_type: }) if match_type.present? && match_type != '全て'
    scope
  end

  def self.build_pitching_stats_hash(user_id, stats)
    ip = stats['innings_pitched'].to_f
    wins = stats['win'].to_i
    losses = stats['loss'].to_i

    {
      user_id:,
      era: safe_divide_round(stats['earned_run'].to_f * INNINGS_PER_GAME, ip, 2),
      complete_games: stats['complete_games'].to_i,
      shutouts: stats['shutouts'].to_i,
      win_percentage: safe_divide_round(wins.to_f, wins + losses, 3),
      k_per_nine: safe_divide_round(stats['strikeouts'].to_f * 9, ip, 3),
      whip: safe_divide_round(stats['base_on_balls'].to_f + stats['hits_allowed'].to_f, ip, 3),
      bb_per_nine: safe_divide_round(stats['base_on_balls'].to_f * 9, ip, 3),
      k_bb: safe_divide_round(stats['strikeouts'].to_f, stats['base_on_balls'].to_i, 3)
    }
  end

  def self.safe_divide_round(numerator, denominator, precision)
    denominator.zero? ? ZERO : (numerator / denominator).round(precision)
  end
end
