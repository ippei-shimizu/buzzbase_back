# frozen_string_literal: true

module Stats
  # 打撃成績の主要スタッツ（NPB 標準指標）を返す Aggregator。
  #
  # batting_averages テーブルを試合単位で SUM して集計し、サーバー側で
  # OBP / SLG / OPS を計算して返す。クライアント側で同じ計算を別途持つと
  # 端数処理がズレるリスクがあるため、計算ロジックはサーバーに集約する。
  #
  # フィルタは HitDirectionAggregator と同じ 5 項目（year / match_type /
  # season_id / tournament_id）を踏襲する。
  class HeadlineStatsAggregator
    include Concerns::FilterableConcern

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] 7 指標 + at_bats（母数）。値はすべて 0 始まりで、母数 0 でも nil を返さない
    def call
      stats = aggregate_stats
      at_bats = stats[:at_bats]
      total_hits = BattingFormulas.total_hits(
        singles: stats[:hit], doubles: stats[:two_base_hit],
        triples: stats[:three_base_hit], home_runs: stats[:home_run]
      )
      obp = BattingFormulas.on_base_percentage(
        total_hits:, base_on_balls: stats[:base_on_balls],
        hit_by_pitch: stats[:hit_by_pitch], at_bats:,
        sacrifice_fly: stats[:sacrifice_fly]
      )
      slg = BattingFormulas.slugging_percentage(total_bases: stats[:total_bases], at_bats:)

      {
        batting_average: BattingFormulas.batting_average(total_hits:, at_bats:),
        hit: total_hits,
        home_run: stats[:home_run],
        runs_batted_in: stats[:runs_batted_in],
        on_base_percentage: obp,
        slugging_percentage: slg,
        ops: BattingFormulas.ops(obp:, slg:),
        at_bats:
      }
    end

    private

    SUM_COLUMNS = %i[
      at_bats hit two_base_hit three_base_hit home_run
      runs_batted_in base_on_balls hit_by_pitch sacrifice_fly total_bases
    ].freeze

    # 8 カラムの SUM を 1 クエリで取得する。scope.sum を都度呼ぶと SELECT が
    # SUM 1 個ずつ 8 本走るため、pick + SUM で 1 本にまとめる。
    # batting_averages の各カラムには NOT NULL 制約が無いため、SUM(NULL) で対象行が
    # 除外されないよう COALESCE で NULL を 0 として扱う（SLG 等の過小計上を防ぐ）。
    def aggregate_stats
      row = filtered_scope.pick(*SUM_COLUMNS.map { |col| Arel.sql("SUM(COALESCE(#{col}, 0))") })
      values = Array.wrap(row).map(&:to_i)
      SUM_COLUMNS.zip(values).to_h
    end

    def filtered_scope
      scope = BattingAverage.joins(game_result: :match_result).where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      scope = apply_season_filter(scope)
      apply_tournament_filter(scope)
    end
  end
end
