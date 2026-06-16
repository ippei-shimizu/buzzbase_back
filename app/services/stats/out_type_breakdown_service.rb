# frozen_string_literal: true

module Stats
  class OutTypeBreakdownService
    # PlateAppearance.out_types の enum 値順を SSoT として保つために、enum 定義を参照する。
    CATEGORY_LABELS = {
      'ground_ball' => 'ゴロ',
      'fly_ball' => 'フライ',
      'line_drive' => 'ライナー',
      'double_play' => '併殺打',
      'foul_fly' => 'ファールフライ'
    }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] breakdown: [{ category, count, percentage }], total: 集計対象の総数
    def call
      counts_by_enum = filtered_scope.where.not(out_type: nil).group(:out_type).count
      total = counts_by_enum.values.sum

      breakdown = CATEGORY_LABELS.map do |enum_key, label|
        count = counts_by_enum.fetch(enum_key, 0)
        percentage = total.zero? ? 0.0 : (count.to_f / total * 100).round(1)
        { category: label, count:, percentage: }
      end

      { breakdown:, total: }
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

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      range_start = Time.zone.local(yr, 1, 1).beginning_of_day
      range_end = Time.zone.local(yr + 1, 1, 1).beginning_of_day
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
