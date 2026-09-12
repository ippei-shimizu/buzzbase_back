# frozen_string_literal: true

module Stats
  # 得点圏（二塁・三塁・一二塁・一三塁・二三塁・満塁）打席の集計サービス。
  #
  # plate_appearances.runners_state の enum が 2..7（second / third / first_second /
  # first_third / second_third / bases_loaded）の打席に絞って at_bats / hits /
  # 長打 / 打率 を返す。
  #
  # 新仕様カラム (runners_state) が必須のため、旧 PA は集計対象外。
  # 母数 0 のときも nil ではなく 0 / 0.0 を返す（クライアント側で「対象データなし」UI に分岐）。
  class RunnersSituationAggregator
    include Concerns::FilterableConcern

    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS
    DOUBLE_HIT_ID = ::Stats::BattingAverageRecalculator::DOUBLE_HIT_ID
    TRIPLE_HIT_ID = ::Stats::BattingAverageRecalculator::TRIPLE_HIT_ID
    HOME_RUN_ID = ::Stats::BattingAverageRecalculator::HOME_RUN_ID

    SCORING_POSITION_STATES = %w[second third first_second first_third second_third bases_loaded].freeze

    # @param date_range [Range<Date>, nil] JST 日単位の絞り込み。週次レポートのように
    #   月境界に揃わない期間を渡すためのもので、月単位の start_month / end_month とは別系統。
    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, # rubocop:disable Metrics/ParameterLists
                   tournament_id: nil, start_month: nil, end_month: nil, date_range: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
      @start_month = start_month
      @end_month = end_month
      @date_range = date_range
    end

    # @return [Hash] at_bats / hits / two_base_hit / three_base_hit / home_run / batting_average
    def call
      counts = aggregate_counts
      {
        batting_average: safe_divide(counts[:hits], counts[:at_bats]),
        at_bats: counts[:at_bats],
        hits: counts[:hits],
        two_base_hit: counts[:two_base_hit],
        three_base_hit: counts[:three_base_hit],
        home_run: counts[:home_run]
      }
    end

    private

    # COUNT(*) FILTER (WHERE ...) で 5 つのカウントを 1 クエリにまとめる。
    # join した plate_results.counted_in_at_bats と plate_appearances.plate_result_id の
    # 両方を FILTER 条件で使う。
    def aggregate_counts
      sql = <<~SQL.squish
        COUNT(*) FILTER (WHERE plate_results.counted_in_at_bats = TRUE) AS at_bats,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id IN (#{HIT_RESULT_IDS.join(',')})) AS hits,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{DOUBLE_HIT_ID}) AS two_base_hit,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{TRIPLE_HIT_ID}) AS three_base_hit,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{HOME_RUN_ID}) AS home_run
      SQL
      row = filtered_scope.joins(:plate_result).pick(Arel.sql(sql))
      values = Array.wrap(row).map(&:to_i)
      %i[at_bats hits two_base_hit three_base_hit home_run].zip(values).to_h
    end

    def filtered_scope
      scope = PlateAppearance.joins(game_result: :match_result)
                             .where(user_id: @user_id, runners_state: SCORING_POSITION_STATES)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      scope = apply_season_filter(scope)
      scope = apply_tournament_filter(scope)
      scope = apply_date_range_filter(scope)
      apply_day_range_filter(scope)
    end

    # date_and_time は UTC 書き込みの unzoned timestamp のため、JST に変換してから
    # 日付比較する（月初・月末をまたぐ深夜帯の試合が前後の日にずれるのを防ぐ）。
    def apply_day_range_filter(scope)
      return scope if @date_range.nil?

      scope.where("DATE(#{Stats::JstDateSql::DATE_AND_TIME_JST_SQL}) BETWEEN ? AND ?",
                  @date_range.first, @date_range.last)
    end
  end
end
