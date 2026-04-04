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

    # plate_result_id → カテゴリ
    RESULT_CATEGORIES = {
      7 => '単打',
      8 => '長打', 9 => '長打',
      10 => '本塁打',
      1 => 'ゴロ',
      2 => 'フライ', 3 => 'フライ', 4 => 'フライ',
      13 => '三振', 14 => '三振',
      15 => '四死球', 16 => '四死球'
    }.freeze

    HR_RESULT_ID = 10

    def call
      base = filtered_scope.where.not(batting_position_id: nil)

      # 方向×結果のクロス集計
      cross = base.group(:batting_position_id, :plate_result_id).count

      # 方向ごとにカテゴリ別件数を集計
      dir_categories = Hash.new { |h, k| h[k] = Hash.new(0) }
      cross.each_value do |cnt|
        cat = RESULT_CATEGORIES[result_id] || 'その他'
        dir_categories[dir_id][cat] += cnt
      end

      # 本塁打を除いた方向別データ
      directions = DIRECTION_LABELS.map do |id, label|
        cats = dir_categories[id]
        non_hr = cats.except('本塁打')
        total = non_hr.values.sum
        top_category = non_hr.max_by { |_, v| v }&.first || 'その他'
        { id:, label:, count: total, top_category: }
      end

      # 方向別の本塁打数
      hr_by_direction = base.where(plate_result_id: HR_RESULT_ID)
                            .group(:batting_position_id)
                            .count

      home_runs = DIRECTION_LABELS.filter_map do |id, label|
        count = hr_by_direction.fetch(id, 0)
        next if count.zero?

        { id:, label:, count: }
      end

      { directions:, home_runs: }
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
