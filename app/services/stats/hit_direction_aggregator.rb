# frozen_string_literal: true

module Stats
  class HitDirectionAggregator
    DIRECTION_LABELS = {
      1 => '投', 2 => '捕', 3 => '一', 4 => '二', 5 => '三',
      6 => '遊', 7 => '左線', 8 => '左', 9 => '左中',
      10 => '中', 11 => '右中', 12 => '右', 13 => '右線'
    }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
    end

    def call
      counts = filtered_scope
               .where.not(batting_position_id: nil)
               .group(:batting_position_id)
               .count

      DIRECTION_LABELS.map do |id, label|
        { id: id, label: label, count: counts.fetch(id, 0) }
      end
    end

    private

    def filtered_scope
      scope = PlateAppearance.joins(game_result: :match_result)
                             .where(user_id: @user_id)
      scope = apply_year_filter(scope)
      scope = apply_match_type_filter(scope)
      scope = apply_season_filter(scope)
      scope
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      scope.where(match_results: {
                    date_and_time: Date.new(@year.to_i, 1, 1)..Date.new(@year.to_i, 12, 31)
                  })
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
