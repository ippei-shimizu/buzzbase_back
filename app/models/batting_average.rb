# `batting_averages.hit` カラムは **単打のみ** を保持する semantics で運用されている
# （v1 フォーム手入力時代から一貫）。NPB / MLB スコアボードの「H（安打）」とは
# 意味が異なる点に注意。
#
# == カラム定義（実データ）
# - `hit`                : 単打数のみ（NPB 用語では「単打」「1B」相当）
# - `two_base_hit`       : 二塁打の本数
# - `three_base_hit`     : 三塁打の本数
# - `home_run`           : 本塁打の本数
# - `total_bases`        : 塁打 = `hit + 2*two_base_hit + 3*three_base_hit + 4*home_run`
#
# == 「安打」として画面に出す値（NPB 標準）
#
# 画面の「安打」ラベルが指す値は **全安打 = `hit + two_base_hit + three_base_hit + home_run`**。
# 直接 `SUM(hit)` を画面表示すると単打数のみが表示され、ユーザーが手計算で
# 「安打 / 打数 = 打率」と検算しても合わない問題が起きる（過去に起きた）。
#
# 集計時は以下の式で安打 / 打率 / OBP / SLG を算出する:
#   total_hits = hit + two_base_hit + three_base_hit + home_run
#   batting_average = total_hits / at_bats
#   OBP = (total_hits + base_on_balls + hit_by_pitch) / (at_bats + base_on_balls + hit_by_pitch + sacrifice_fly)
#   SLG = total_bases / at_bats
#
# == 各レイヤーの実装
# - 本モデル `aggregate_columns` / `stats_columns`     : 内部で `SUM(hit + 2B + 3B + HR)` を返す
# - `Stats::HeadlineStatsAggregator` (stats タブ主要)  : 同様に total_hits を導出
# - `Stats::AdditionalStatsAggregator` (追加指標)      : 同様
# - `Stats::BattingTrendAggregator` (打撃推移)         : 同様
# - `Stats::BattingStatsTableService` (打撃成績表)     : 同様
# - `Stats::BattingAverageRecalculator` (書き込み側)   : 新仕様 PA から hit カラムを
#                                                         書き込むときは SINGLE_HIT_ID (= 7) のみ
#                                                         をカウントし、旧データと同じ semantics を保つ
#
# == 単打のみの値が欲しい場合
# 個別レコード列の `hit` を直接参照する（マイページ等の表示には出さない方針）。
class BattingAverage < ApplicationRecord
  belongs_to :game_result
  belongs_to :user

  validates :game_result_id, uniqueness: true
  validate :must_have_any_stats

  ZERO = 0

  # NPB / MLB スコアボードでいう「安打 (H)」相当の総安打数を返す。
  # `hit` カラムは単打のみを保持する semantics のため、per-game 表示で
  # 画面に「安打 N」と出す値はこのメソッドを必ず通すこと（直接 `hit` を
  # 公開すると単打のみが表示され、二塁打 / 三塁打 / 本塁打が抜け落ちる）。
  def total_hits
    hit.to_i + two_base_hit.to_i + three_base_hit.to_i + home_run.to_i
  end

  # per-game レスポンスで画面表示用に attributes を返す。`hit` を全安打に
  # 差し替えた状態の Hash で、ダッシュボードや試合一覧などレコードを直接
  # JSON として返す controller / model helper で利用する（v1 batting_averages
  # の編集系 API は raw カラムが必要なので、こちらは使わない）。
  def display_attributes
    attributes.merge('hit' => total_hits)
  end

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
     # `hit` カラムは本番運用上「単打のみ」を保持するが、画面で「安打」として
     # 表示する値は NPB 標準の全安打（単打 + 二塁打 + 三塁打 + 本塁打）。
     # マイページ / ダッシュボード / ランキング / グループスタッツの安打表示を
     # NPB 標準に揃え、stats タブの主要スタッツとも一致させる。
     'SUM(hit + two_base_hit + three_base_hit + home_run) AS hit',
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

  def self.stats_columns
    ['SUM(hit + two_base_hit + three_base_hit + home_run) AS total_hits',
     'SUM(hit) AS hit',
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

  def self.calculate_slugging_percentage(stats)
    at_bats = stats['at_bats'].to_i
    total_bases = stats['hit'].to_i + (stats['two_base_hit'].to_i * 2) +
                  (stats['three_base_hit'].to_i * 3) + (stats['home_run'].to_i * 4)
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
