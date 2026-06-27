# frozen_string_literal: true

module Stats
  class PlateAppearanceBreakdownService
    include Concerns::FilterableConcern

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

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
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
      scope = apply_season_filter(scope)
      apply_tournament_filter(scope)
    end
  end
end
