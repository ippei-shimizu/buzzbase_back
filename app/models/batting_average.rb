# `batting_averages.hit` カラムは **単打 + 二塁打 + 三塁打 + 本塁打 を合算した
# 全安打数** を保持する（NPB / MLB スコアボードの「H 列」と同じセマンティクス）。
# 旧仕様の手入力フォームも、新仕様の `Stats::BattingAverageRecalculator`
# (`HIT_RESULT_IDS = [7, 8, 9, 10]` を全件カウント) も同じ意味で書き込んでおり、
# `two_base_hit` / `three_base_hit` / `home_run` カラムは「うち何本が何塁打か」
# という内訳を持つ。
#
# 集計式を組むときは
#   - 総安打 = SUM(hit)
#   - 単打数 = SUM(hit) - SUM(two_base_hit) - SUM(three_base_hit) - SUM(home_run)
#   - 塁打 (TB) = SUM(hit) + SUM(two_base_hit) + 2*SUM(three_base_hit) + 3*SUM(home_run)
# となる点に注意（`hit + 2*two_base_hit + ...` のように単打式で組むと二重計上）。
class BattingAverage < ApplicationRecord
  belongs_to :game_result
  belongs_to :user

  validates :game_result_id, uniqueness: true
  validate :must_have_any_stats

  ZERO = 0

  def self.aggregate_for_user(user_id)
    aggregate_query.where(user_id:)
  end

  def self.aggregate_for_users(user_ids)
    aggregate_query.where(user_id: user_ids)
  end

  def self.aggregate_query
    select(*aggregate_columns).group('batting_averages.user_id')
  end

  def self.aggregate_columns
    ['batting_averages.user_id',
     'COUNT(batting_averages.game_result_id) AS number_of_matches',
     'SUM(times_at_bat) AS times_at_bat',
     'SUM(at_bats) AS at_bats',
     'SUM(hit) AS hit',
     'SUM(two_base_hit) AS two_base_hit',
     'SUM(three_base_hit) AS three_base_hit',
     'SUM(home_run) AS home_run',
     'SUM(total_bases) AS total_bases',
     'SUM(runs_batted_in) AS runs_batted_in',
     'SUM(run) AS run',
     'SUM(strike_out) AS strike_out',
     'SUM(base_on_balls) AS base_on_balls',
     'SUM(hit_by_pitch) AS hit_by_pitch',
     'SUM(sacrifice_hit) AS sacrifice_hit',
     'SUM(sacrifice_fly) AS sacrifice_fly',
     'SUM(stealing_base) AS stealing_base',
     'SUM(caught_stealing) AS caught_stealing',
     'SUM(error) AS error']
  end

  def self.filtered_aggregate_for_user(user_id, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
    scope = joins(game_result: :match_result).select(*aggregate_columns)
    scope = apply_filters(scope, year, match_type, season_id:, tournament_id:)
    scope.where(batting_averages: { user_id: }).group('batting_averages.user_id')
  end

  def self.stats_for_user(user_id, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
    if year.present? || match_type.present? || season_id.present? || tournament_id.present?
      scope = apply_filters(unscoped.joins(game_result: :match_result), year, match_type, season_id:, tournament_id:)
      result = scope.where(batting_averages: { user_id: }).select(*stats_columns).reorder(nil).take
    else
      result = unscoped.where(user_id:).select(*stats_columns).reorder(nil).take
    end

    return nil unless result

    build_stats_hash(user_id, result.attributes)
  end

  def self.bulk_stats_for_users(user_ids)
    results = unscoped.where(user_id: user_ids)
                      .select('batting_averages.user_id', *stats_columns)
                      .group('batting_averages.user_id')

    results.each_with_object({}) do |result, hash|
      hash[result.user_id] = build_stats_hash(result.user_id, result.attributes)
    end
  end

  # filtered_stats_for_user を stats_for_user に統合（後方互換エイリアス）
  class << self
    alias filtered_stats_for_user stats_for_user
  end

  def self.apply_filters(scope, year, match_type, season_id: nil, tournament_id: nil)
    scope = scope.where(match_results: { date_and_time: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31) }) if year.present? && year.to_s != '通算'
    scope = scope.where(match_results: { match_type: }) if match_type.present? && match_type != '全て'
    scope = scope.where(game_results: { season_id: }) if season_id.present?
    scope = scope.where(match_results: { tournament_id: }) if tournament_id.present?
    scope
  end

  # `hit` カラムは全安打を含むため、総安打 = SUM(hit)。
  # 以前は `SUM(hit + 2B + 3B + HR)` と書いていたが、2B/3B/HR を二重計上して
  # 打率 / OBP / OPS / ISOD が上振れていた既存バグの修正。
  # `hit` 単独の SUM は不要（消費側は total_hits を参照する）。同じ式を二重に
  # SELECT すると「hit と total_hits の値が違う」という誤読の芽になる。
  def self.stats_columns
    ['SUM(hit) AS total_hits',
     'SUM(two_base_hit) AS two_base_hit',
     'SUM(three_base_hit) AS three_base_hit',
     'SUM(home_run) AS home_run',
     'SUM(at_bats) AS at_bats',
     'SUM(hit_by_pitch + base_on_balls) AS on_base',
     'SUM(sacrifice_hit) AS sacrifice_hits',
     'SUM(sacrifice_fly) AS sacrifice_fly',
     'SUM(strike_out) AS strike_outs',
     'SUM(base_on_balls) AS base_on_balls',
     'SUM(hit_by_pitch) AS hit_by_pitch']
  end

  def self.build_stats_hash(user_id, stats)
    {
      user_id:,
      total_hits: stats['total_hits'].to_i,
      batting_average: safe_divide(stats['total_hits'].to_f, stats['at_bats'].to_i),
      on_base_percentage: calculate_on_base_percentage(stats),
      iso: safe_divide(
        (stats['two_base_hit'].to_i + (stats['three_base_hit'].to_i * 2) + (stats['home_run'].to_i * 3)).to_f,
        stats['at_bats'].to_i
      ),
      ops: calculate_ops(stats).round(3),
      bb_per_k: safe_divide(stats['base_on_balls'].to_f, stats['strike_outs'].to_i),
      isod: calculate_isod(stats).round(3),
      slugging_percentage: calculate_slugging_percentage(stats).round(3)
    }
  end

  def self.safe_divide(numerator, denominator)
    denominator.zero? ? ZERO : (numerator / denominator).round(3)
  end

  def self.calculate_on_base_percentage(stats)
    denominator = stats['at_bats'].to_i + stats['base_on_balls'].to_i +
                  stats['hit_by_pitch'].to_i + stats['sacrifice_fly'].to_i
    numerator = stats['total_hits'].to_f + stats['base_on_balls'].to_i + stats['hit_by_pitch'].to_i
    denominator.zero? ? ZERO : (numerator / denominator).round(3)
  end

  def self.calculate_ops(stats)
    slg = calculate_slugging_percentage(stats)
    obp = calculate_on_base_percentage(stats)
    (obp + slg).round(3)
  end

  def self.calculate_isod(stats)
    avg = safe_divide(stats['total_hits'].to_f, stats['at_bats'].to_i)
    obp = calculate_on_base_percentage(stats)
    (obp - avg).round(3)
  end

  # `total_hits` は全安打（単打 + 2B + 3B + HR）なので、塁打 (TB) は
  # 単打×1 + 2B×2 + 3B×3 + HR×4 を展開して
  # `total_hits + 2B + 2*3B + 3*HR` に等しい。以前は `hit + 2*2B + 3*3B + 4*HR`
  # と書いていたが、これは hit を単打のみと解釈した式で 2B/3B/HR を二重計上していた。
  def self.calculate_slugging_percentage(stats)
    at_bats = stats['at_bats'].to_i
    total_bases = stats['total_hits'].to_i + stats['two_base_hit'].to_i +
                  (stats['three_base_hit'].to_i * 2) + (stats['home_run'].to_i * 3)
    at_bats.zero? ? ZERO : total_bases.to_f / at_bats
  end

  private

  def must_have_any_stats
    stat_fields = [
      times_at_bat, at_bats, hit, two_base_hit, three_base_hit, home_run,
      total_bases, runs_batted_in, run, strike_out, base_on_balls,
      hit_by_pitch, sacrifice_hit, sacrifice_fly, stealing_base,
      caught_stealing, error
    ]
    return unless stat_fields.all? { |v| v.nil? || v.to_f.zero? }

    errors.add(:base, '打撃成績が未入力です')
  end
end
