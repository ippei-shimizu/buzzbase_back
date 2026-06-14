# frozen_string_literal: true

module Stats
  class HitLocationAggregator
    # 値の食い違いを避けるため BattingAverageRecalculator の HIT_RESULT_IDS を SSoT として参照する。
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS
    # PlateAppearanceBreakdownService::CATEGORIES と分類を揃える。
    # id:19 (併殺打) はそちらでも 'その他' 扱いなので、ここでも 'out' ではなく 'other' に落とす。
    OUT_RESULT_IDS = [1, 2, 3, 4].freeze

    # @param user_id [Integer] 対象ユーザー ID
    # @param year [Integer, String, nil] 集計対象の年（nil または '通算' で全期間）
    # @param match_type [String, nil] 試合種別フィルタ
    # @param season_id [Integer, String, nil] シーズン ID フィルタ
    # @param tournament_id [Integer, String, nil] 大会 ID フィルタ
    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] points: 各打席の (x, y, category, plate_result_id) 配列
    def call
      rows = filtered_scope
             .where('hit_location_x IS NOT NULL AND hit_location_y IS NOT NULL')
             .pluck(:hit_location_x, :hit_location_y, :plate_result_id)

      points = rows.map do |x, y, result_id|
        {
          x: x.to_f,
          y: y.to_f,
          category: categorize(result_id),
          plate_result_id: result_id
        }
      end

      { points: }
    end

    private

    def categorize(result_id)
      return 'hit' if HIT_RESULT_IDS.include?(result_id)
      return 'out' if OUT_RESULT_IDS.include?(result_id)

      'other'
    end

    def filtered_scope
      scope = PlateAppearance.joins(game_result: :match_result)
                             .where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      scope = apply_season_filter(scope)
      apply_tournament_filter(scope)
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
  end
end
