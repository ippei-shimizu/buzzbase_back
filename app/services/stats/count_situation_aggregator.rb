# frozen_string_literal: true

module Stats
  # カウント状況別（初球 / 有利カウント / 追い込み）の打席集計サービス。
  #
  # plate_appearances の first_pitch_swing / final_balls / final_strikes は
  # 新仕様で記録されたカラムなので、これらが NULL の旧 PA は集計対象外。
  # filtered_scope 段階で `final_strikes IS NOT NULL` を入れることで、
  # 新仕様の PA だけを 3 条件で抽出する。
  #
  # 母数 0 のときは batting_average を 0.0 で返し、クライアント側で
  # 「対象データなし」UI に分岐させる。
  class CountSituationAggregator
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS

    SITUATIONS = {
      first_pitch: 'plate_appearances.first_pitch_swing = TRUE',
      favorable_count: 'plate_appearances.final_balls > plate_appearances.final_strikes',
      pinch_count: 'plate_appearances.final_strikes = 2'
    }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] :first_pitch / :favorable_count / :pinch_count の各セットと
    #   :total_target_pa（新仕様で記録された対象打席数）
    def call
      counts = aggregate_counts
      {
        first_pitch: build_result(counts[:first_pitch_at_bats], counts[:first_pitch_hits]),
        favorable_count: build_result(counts[:favorable_at_bats], counts[:favorable_hits]),
        pinch_count: build_result(counts[:pinch_at_bats], counts[:pinch_hits]),
        total_target_pa: counts[:total_target_pa]
      }
    end

    private

    # 3 条件 × (at_bats, hits) + total_target_pa を 1 クエリで集約する。
    def aggregate_counts
      sql = <<~SQL.squish
        COUNT(*) AS total_target_pa,
        COUNT(*) FILTER (WHERE plate_results.counted_in_at_bats = TRUE
                           AND #{SITUATIONS[:first_pitch]}) AS first_pitch_at_bats,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id IN (#{HIT_RESULT_IDS.join(',')})
                           AND #{SITUATIONS[:first_pitch]}) AS first_pitch_hits,
        COUNT(*) FILTER (WHERE plate_results.counted_in_at_bats = TRUE
                           AND #{SITUATIONS[:favorable_count]}) AS favorable_at_bats,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id IN (#{HIT_RESULT_IDS.join(',')})
                           AND #{SITUATIONS[:favorable_count]}) AS favorable_hits,
        COUNT(*) FILTER (WHERE plate_results.counted_in_at_bats = TRUE
                           AND #{SITUATIONS[:pinch_count]}) AS pinch_at_bats,
        COUNT(*) FILTER (WHERE plate_appearances.plate_result_id IN (#{HIT_RESULT_IDS.join(',')})
                           AND #{SITUATIONS[:pinch_count]}) AS pinch_hits
      SQL
      row = filtered_scope.joins(:plate_result).pick(Arel.sql(sql))
      values = Array.wrap(row).map(&:to_i)
      %i[total_target_pa
         first_pitch_at_bats first_pitch_hits
         favorable_at_bats favorable_hits
         pinch_at_bats pinch_hits].zip(values).to_h
    end

    def build_result(at_bats, hits)
      {
        at_bats:,
        hits:,
        batting_average: safe_divide(hits, at_bats)
      }
    end

    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id)
                               .where.not(final_strikes: nil)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                  "#{yr}-01-01 00:00:00", "#{yr + 1}-01-01 00:00:00")
    end

    def apply_match_type_filter(scope)
      return scope if @match_type.blank? || @match_type == '全て'

      scope.where(match_results: { match_type: @match_type })
    end

    def apply_season_filter(scope)
      return scope if @season_id.blank?

      scope.where(game_results: { season_id: @season_id })
    end

    def apply_tournament_filter(scope)
      return scope if @tournament_id.blank?

      scope.where(match_results: { tournament_id: @tournament_id })
    end

    def safe_divide(numerator, denominator)
      return 0.0 if denominator.to_i.zero?

      (numerator.to_f / denominator).round(3)
    end
  end
end
