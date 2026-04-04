# frozen_string_literal: true

module Stats
  class HitDirectionAggregator
    DIRECTION_LABELS = {
      1 => '投', 2 => '捕', 3 => '一', 4 => '二', 5 => '三',
      6 => '遊', 7 => '左線', 8 => '左', 9 => '左中',
      10 => '中', 11 => '右中', 12 => '右', 13 => '右線'
    }.freeze

    # batting_position_id(旧9方向) → hit_direction_id(新13方向) への変換
    LEGACY_TO_NEW = {
      1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6,
      7 => 8, 8 => 10, 9 => 12
    }.freeze

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

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
    end

    def call
      dir_categories = aggregate_direction_categories

      { directions: build_directions(dir_categories), home_runs: build_home_runs(dir_categories) }
    end

    private

    def aggregate_direction_categories
      base = filtered_scope
      direction_sql = build_direction_sql

      cross = base
              .where("#{direction_sql} IS NOT NULL AND #{direction_sql} > 0")
              .group(Arel.sql(direction_sql), :plate_result_id)
              .count

      dir_categories = Hash.new { |h, k| h[k] = Hash.new(0) }
      cross.each do |(dir_id, result_id), cnt| # rubocop:disable Style/HashEachMethods
        cat = RESULT_CATEGORIES[result_id] || 'その他'
        dir_categories[dir_id][cat] += cnt
      end
      dir_categories
    end

    def build_direction_sql
      <<~SQL.squish
        COALESCE(
          plate_appearances.hit_direction_id,
          CASE plate_appearances.batting_position_id
            #{LEGACY_TO_NEW.map { |old_id, new_id| "WHEN #{old_id} THEN #{new_id}" }.join(' ')}
            ELSE NULL
          END
        )
      SQL
    end

    def build_directions(dir_categories)
      DIRECTION_LABELS.map do |id, label|
        cats = dir_categories[id]
        non_hr = cats.except('本塁打')
        total = non_hr.values.sum
        top_category = non_hr.max_by { |_, v| v }&.first || 'その他'
        { id:, label:, count: total, top_category: }
      end
    end

    def build_home_runs(dir_categories)
      DIRECTION_LABELS.filter_map do |id, label|
        count = dir_categories[id]['本塁打']
        next if count.zero?

        { id:, label:, count: }
      end
    end

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
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time <= ?',
                  "#{yr}-01-01 00:00:00", "#{yr}-12-31 23:59:59")
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
