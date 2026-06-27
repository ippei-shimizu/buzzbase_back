# frozen_string_literal: true

module Stats
  # 打撃成績の推移グラフ用 Aggregator。
  #
  # batting_averages テーブルを試合単位 (granularity=game) もしくは
  # 月単位 (granularity=month) で時系列集計し、各時点の打率 / OBP / SLG / OPS を返す。
  # OBP/SLG/OPS の計算式は HeadlineStatsAggregator と同一に揃え、フロント側で
  # 同じ計算を持つことによる端数ズレを防ぐ。
  #
  # granularity=game は **累積** を返す（最初の試合から各時点までの通算成績）。
  # granularity=month は **その月単独** を返す（各月でリセット）。
  class BattingTrendAggregator # rubocop:disable Metrics/ClassLength
    include Concerns::FilterableConcern

    SUM_COLUMNS = %i[
      at_bats hit two_base_hit three_base_hit home_run
      total_bases base_on_balls hit_by_pitch sacrifice_fly
    ].freeze

    # 受け付ける granularity:
    # - `game`: 開幕から各試合時点までの **累積**（シーズン通算の推移）
    # - `month`: 月単独（各月でリセット）
    # - `year`: 年単独（シーズン比較）
    # - `recent_games`: 直近 RECENT_GAMES_WINDOW 試合だけを取り出してその中で累積
    SUPPORTED_GRANULARITIES = %w[game month year recent_games season].freeze

    # 「直近 N 試合」モードの N。短期コンディションの可視化に使うため
    # 10 に固定する（NPB / MLB の hot streak 表示で一般的な値）。
    RECENT_GAMES_WINDOW = 10

    def initialize(user_id:, granularity: 'game', # rubocop:disable Metrics/ParameterLists
                   year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @granularity = SUPPORTED_GRANULARITIES.include?(granularity.to_s) ? granularity.to_s : 'game'
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] granularity と points 配列。
    #   points の各要素は key / label / batting_average / on_base_percentage /
    #   slugging_percentage / ops / at_bats_in_period / cumulative_at_bats を持つ。
    def call
      points = case @granularity
               when 'month' then aggregate_by_month
               when 'year' then aggregate_by_year
               when 'season' then aggregate_by_season
               when 'recent_games' then aggregate_by_recent_games
               else aggregate_by_game
               end
      { granularity: @granularity, points: }
    end

    private

    # 各試合の SUM 列をまとめて取得 → 累積で打率等を計算。
    # 日付は in_time_zone で Rails の TZ 設定（本番: Asia/Tokyo）に揃え、
    # recent_games モードと同じ key / label が出るようにする。
    def aggregate_by_game
      rows = aggregate_per_game_rows
      cumulative = SUM_COLUMNS.index_with { 0 }
      rows.map do |row|
        SUM_COLUMNS.each { |col| cumulative[col] += row[col] }
        local_date = row[:date].in_time_zone
        build_point(
          key: local_date.to_date.iso8601,
          label: local_date.strftime('%-m/%-d'),
          period_stats: row,
          cumulative_stats: cumulative
        )
      end
    end

    # 月ごとの SUM をそのまま使い、月単独の打率等を返す（cumulative も月単独に合わせる）。
    def aggregate_by_month
      aggregate_per_month_rows.map do |row|
        build_point(
          key: row[:key],
          label: "#{row[:month]}月",
          period_stats: row,
          cumulative_stats: row
        )
      end
    end

    # 年ごとの SUM をそのまま使い、年単独の打率等を返す。
    def aggregate_by_year
      aggregate_per_year_rows.map do |row|
        build_point(
          key: row[:key],
          label: "#{row[:year]}年",
          period_stats: row,
          cumulative_stats: row
        )
      end
    end

    # シーズンごとの SUM をそのまま使い、シーズン単独の打率等を返す（シーズン跨ぎ比較）。
    # season_id が未割り当ての試合は集計対象外（INNER JOIN seasons）。
    def aggregate_by_season
      aggregate_per_season_rows.map do |row|
        build_point(
          key: row[:key],
          label: row[:season_name],
          period_stats: row,
          cumulative_stats: row
        )
      end
    end

    # 直近 N 試合だけを取り出し、その中で累積した打率等の推移を返す。
    # X 軸は最大 N 点になり、ユーザーの「直近 N 試合のトレンドが見たい」という
    # 期待と一致する（全期間の移動平均ではない）。
    # 直近 N 試合の最初の点はサンプルが少なく荒い値になるが、これは仕様。
    def aggregate_by_recent_games
      recent_rows = aggregate_per_game_rows(limit: RECENT_GAMES_WINDOW)
      cumulative = SUM_COLUMNS.index_with { 0 }
      recent_rows.map do |row|
        SUM_COLUMNS.each { |col| cumulative[col] += row[col] }
        local_date = row[:date].in_time_zone
        build_point(
          key: local_date.to_date.iso8601,
          label: local_date.strftime('%-m/%-d'),
          period_stats: row,
          cumulative_stats: cumulative
        )
      end
    end

    # `limit` を渡したときは DB 側で「日付降順 LIMIT → 結果を昇順に戻す」で
    # 直近 N 試合だけ取り出す。全試合を pluck してから Ruby で .last(N) する
    # ナイーブ実装はユーザーのシーズンが長くなるほど無駄が増えるため避ける。
    def aggregate_per_game_rows(limit: nil)
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      scope = filtered_scope
              .group('game_results.id, match_results.date_and_time')
      # 同一日時に複数試合があると取得順が非決定的になるため、game_results.id を
      # 二次キーにして直近 N 試合の取り出しと並び順を安定させる。
      scope = if limit
                scope.order(Arel.sql('match_results.date_and_time DESC, game_results.id DESC')).limit(limit)
              else
                scope.order(Arel.sql('match_results.date_and_time ASC, game_results.id ASC'))
              end
      rows = scope.pluck(Arel.sql("match_results.date_and_time, #{sum_sql}"))
      rows.reverse! if limit

      rows.map do |row|
        date, *values = row
        { date: }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def aggregate_per_month_rows
      year_sql = Stats::JstDateSql::YEAR_JST_INT_SQL
      month_sql = Stats::JstDateSql::MONTH_JST_INT_SQL
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      rows = filtered_scope
             .group(Arel.sql("#{year_sql}, #{month_sql}"))
             .order(Arel.sql("#{year_sql} ASC, #{month_sql} ASC"))
             .pluck(Arel.sql("#{year_sql}, #{month_sql}, #{sum_sql}"))

      rows.map do |row|
        year, month, *values = row
        {
          key: format('%<year>04d-%<month>02d', year: year.to_i, month: month.to_i),
          month: month.to_i,
          year: year.to_i
        }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def aggregate_per_year_rows
      year_sql = Stats::JstDateSql::YEAR_JST_INT_SQL
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      rows = filtered_scope
             .group(Arel.sql(year_sql))
             .order(Arel.sql("#{year_sql} ASC"))
             .pluck(Arel.sql("#{year_sql}, #{sum_sql}"))

      rows.map do |row|
        year, *values = row
        {
          key: format('%<year>04d', year: year.to_i),
          year: year.to_i
        }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def aggregate_per_season_rows
      sum_sql = SUM_COLUMNS.map { |col| "SUM(COALESCE(batting_averages.#{col}, 0)) AS #{col}" }.join(', ')
      rows = filtered_scope
             .joins('INNER JOIN seasons ON seasons.id = game_results.season_id')
             .group('seasons.id, seasons.name, seasons.created_at')
             .order(Arel.sql('seasons.created_at ASC'))
             .pluck(Arel.sql("seasons.id, seasons.name, #{sum_sql}"))

      rows.map do |row|
        season_id, season_name, *values = row
        {
          key: "season-#{season_id}",
          season_name:
        }.merge(SUM_COLUMNS.zip(values.map(&:to_i)).to_h)
      end
    end

    def build_point(key:, label:, period_stats:, cumulative_stats:)
      at_bats = cumulative_stats[:at_bats]
      total_hits = BattingFormulas.total_hits(
        singles: cumulative_stats[:hit], doubles: cumulative_stats[:two_base_hit],
        triples: cumulative_stats[:three_base_hit], home_runs: cumulative_stats[:home_run]
      )
      obp = BattingFormulas.on_base_percentage(
        total_hits:, base_on_balls: cumulative_stats[:base_on_balls],
        hit_by_pitch: cumulative_stats[:hit_by_pitch], at_bats:,
        sacrifice_fly: cumulative_stats[:sacrifice_fly]
      )
      slg = BattingFormulas.slugging_percentage(total_bases: cumulative_stats[:total_bases], at_bats:)

      {
        key:,
        label:,
        batting_average: BattingFormulas.batting_average(total_hits:, at_bats:),
        on_base_percentage: obp,
        slugging_percentage: slg,
        ops: BattingFormulas.ops(obp:, slg:),
        at_bats_in_period: period_stats[:at_bats].to_i,
        cumulative_at_bats: at_bats
      }
    end

    def filtered_scope
      @filtered_scope ||= begin
        scope = BattingAverage.joins(game_result: :match_result).where(user_id: @user_id)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end
  end
end
