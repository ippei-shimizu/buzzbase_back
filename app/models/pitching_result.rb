class PitchingResult < ApplicationRecord
  belongs_to :game_result
  belongs_to :user

  validate :must_have_any_stats

  ZERO = 0

  # 投手集計クエリは ERA / K/9 / BB/9 を「試合のイニング制（match_results.inning_format）で加重平均」する。
  # 従来の `× 9 / 投球回` 固定ではなく、各試合のイニング制（7 or 9）を係数として掛けることで、
  # 7回制の試合では「× 7」で換算され、混在試合でも実力が正しく反映される。
  # match_results は game_result 経由で必ず JOIN する必要がある。
  def self.pitching_aggregate_for_user(user_id)
    pitching_aggregate_query.where(pitching_results: { user_id: })
  end

  def self.pitching_aggregate_for_users(user_ids)
    pitching_aggregate_query.where(pitching_results: { user_id: user_ids })
  end

  def self.pitching_aggregate_query
    joins(game_result: :match_result)
      .select(*pitching_aggregate_columns)
      .group('pitching_results.user_id')
  end

  def self.pitching_aggregate_columns
    ['pitching_results.user_id',
     'SUM(CASE WHEN pitching_results.innings_pitched > 0 THEN 1 ELSE 0 END) AS number_of_appearances',
     'SUM(pitching_results.win) AS win',
     'SUM(CASE WHEN pitching_results.got_to_the_distance THEN 1 ELSE 0 END) AS complete_games',
     "SUM(CASE WHEN pitching_results.got_to_the_distance = 't' AND pitching_results.run_allowed = 0 THEN 1 ELSE 0 END) AS shutouts",
     'SUM(pitching_results.loss) AS loss',
     'SUM(pitching_results.hold) AS hold',
     'SUM(pitching_results.saves) AS saves',
     'ROUND(SUM(pitching_results.innings_pitched)::numeric, 2) AS innings_pitched',
     'SUM(pitching_results.hits_allowed) AS hits_allowed',
     'SUM(pitching_results.home_runs_hit) AS home_runs_hit',
     'SUM(pitching_results.strikeouts) AS strikeouts',
     'SUM(pitching_results.base_on_balls) AS base_on_balls',
     'SUM(pitching_results.hit_by_pitch) AS hit_by_pitch',
     'SUM(pitching_results.run_allowed) AS run_allowed',
     'SUM(pitching_results.earned_run) AS earned_run',
     'SUM(pitching_results.number_of_pitches) AS number_of_pitches',
     'SUM(pitching_results.earned_run * match_results.inning_format) AS weighted_earned_run',
     'SUM(pitching_results.strikeouts * match_results.inning_format) AS weighted_strikeouts',
     'SUM(pitching_results.base_on_balls * match_results.inning_format) AS weighted_base_on_balls']
  end

  def self.filtered_pitching_aggregate_for_user(user_id, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
    scope = joins(game_result: :match_result).select(*pitching_aggregate_columns)
    scope = apply_filters(scope, year, match_type, season_id:, tournament_id:)
    scope.where(pitching_results: { user_id: }).group('pitching_results.user_id')
  end

  def self.pitching_stats_for_user(user_id, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
    if year.present? || match_type.present? || season_id.present? || tournament_id.present?
      scope = apply_filters(joins(game_result: :match_result), year, match_type, season_id:, tournament_id:)
      result = scope.select(*pitching_aggregate_columns)
                    .where(pitching_results: { user_id: })
                    .group('pitching_results.user_id').take
    else
      result = pitching_aggregate_query.find_by(pitching_results: { user_id: })
    end

    return nil unless result

    build_pitching_stats_hash(user_id, result.attributes)
  end

  def self.bulk_pitching_stats_for_users(user_ids)
    results = pitching_aggregate_query.where(pitching_results: { user_id: user_ids })

    results.each_with_object({}) do |result, hash|
      hash[result.user_id] = build_pitching_stats_hash(result.user_id, result.attributes)
    end
  end

  # filtered_pitching_stats_for_user を pitching_stats_for_user に統合（後方互換エイリアス）
  class << self
    alias filtered_pitching_stats_for_user pitching_stats_for_user
  end

  def self.apply_filters(scope, year, match_type, season_id: nil, tournament_id: nil)
    scope = scope.where(match_results: { date_and_time: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31) }) if year.present? && year.to_s != '通算'
    scope = scope.where(match_results: { match_type: }) if match_type.present? && match_type != '全て'
    scope = scope.where(game_results: { season_id: }) if season_id.present?
    scope = scope.where(match_results: { tournament_id: }) if tournament_id.present?
    scope
  end

  # @param user_id [Integer]
  # @param stats [Hash] 集計クエリの行（pitching_aggregate_columns で生成された値を含む）
  # @return [Hash{Symbol=>Numeric}] ERA / K9 / BB9 / WHIP 等の計算済み統計
  # ERA・K/9・BB/9 は試合のイニング制で加重した分子（weighted_*）を投球回で割って算出する。
  def self.build_pitching_stats_hash(user_id, stats)
    ip = stats['innings_pitched'].to_f
    wins = stats['win'].to_i
    losses = stats['loss'].to_i

    {
      user_id:,
      era: safe_divide_round(stats['weighted_earned_run'].to_f, ip, 2),
      complete_games: stats['complete_games'].to_i,
      shutouts: stats['shutouts'].to_i,
      win_percentage: safe_divide_round(wins.to_f, wins + losses, 3),
      k_per_nine: safe_divide_round(stats['weighted_strikeouts'].to_f, ip, 3),
      whip: safe_divide_round(stats['base_on_balls'].to_f + stats['hits_allowed'].to_f, ip, 3),
      bb_per_nine: safe_divide_round(stats['weighted_base_on_balls'].to_f, ip, 3),
      k_bb: safe_divide_round(stats['strikeouts'].to_f, stats['base_on_balls'].to_i, 3),
      number_of_pitches: stats['number_of_pitches'].to_i
    }
  end

  def self.safe_divide_round(numerator, denominator, precision)
    denominator.zero? ? ZERO : (numerator / denominator).round(precision)
  end

  private

  def must_have_any_stats
    stat_fields = [
      win, loss, hold, saves, innings_pitched, number_of_pitches,
      run_allowed, earned_run, hits_allowed, home_runs_hit,
      strikeouts, base_on_balls, hit_by_pitch
    ]
    return unless stat_fields.all? { |v| v.nil? || v.to_f.zero? } && !got_to_the_distance

    errors.add(:base, '投手成績が未入力です')
  end
end
