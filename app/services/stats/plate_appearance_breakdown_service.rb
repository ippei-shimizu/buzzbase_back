# frozen_string_literal: true

module Stats
  class PlateAppearanceBreakdownService
    CATEGORIES = {
      '単打' => [7],
      '長打' => [8, 9],
      '本塁打' => [10],
      'ゴロ' => [1],
      'フライ' => [2, 3, 4],
      '三振' => [13, 14],
      '四死球' => [15, 16],
      'その他' => [5, 6, 11, 12, 17, 18, 19]
    }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
    end

    def call
      counts_by_result = filtered_scope
                         .where.not(plate_result_id: nil)
                         .group(:plate_result_id)
                         .count

      total = counts_by_result.values.sum

      CATEGORIES.map do |category, result_ids|
        count = result_ids.sum { |id| counts_by_result.fetch(id, 0) }
        percentage = total.zero? ? 0.0 : (count.to_f / total * 100).round(1)
        { category:, count:, percentage: }
      end
    end

    private

    def filtered_scope
      scope = PlateAppearance.joins(game_result: :match_result)
                             .where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      apply_season_filter(scope)
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
  end
end
