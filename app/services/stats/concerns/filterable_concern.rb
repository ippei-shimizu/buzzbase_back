# frozen_string_literal: true

module Stats
  module Concerns
    # stats 系 Aggregator / Service が共通で受け取るフィルタ 4 種を提供する。
    # include 側は `@year` / `@match_type` / `@season_id` / `@tournament_id`
    # を `initialize` で必ずセットしている前提（未設定時は blank? で素通り）。
    module FilterableConcern
      extend ActiveSupport::Concern

      private

      def apply_year_filter(scope)
        return scope if @year.blank? || @year.to_s == '通算'

        yr = @year.to_i
        range_start = Time.zone.local(yr, 1, 1)
        range_end = Time.zone.local(yr + 1, 1, 1)
        scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                    range_start, range_end)
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
end
