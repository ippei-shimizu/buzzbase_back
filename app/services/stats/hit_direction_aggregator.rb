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
    # 値の食い違いを避けるため BattingAverageRecalculator の HIT_RESULT_IDS を SSoT として参照する。
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS
    TWO_BASE_RESULT_ID = 8
    THREE_BASE_RESULT_ID = 9
    TOTAL_BASES_PER_RESULT = { 7 => 1, 8 => 2, 9 => 3, 10 => 4 }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # 方向別の打球集計を返す。
    #
    # @return [Hash{Symbol=>Array<Hash>}] :directions と :home_runs を持つハッシュ。
    #   `directions` の各要素はキー `:count` と `:hits` の意味が異なる点に注意：
    #   - `count`: 本塁打を **除いた** 打球数。スキャッターチャート（バブル）の
    #     方向別件数として表示するために、本塁打を別グループ (`home_runs`) に
    #     寄せて二重表示しない設計になっている。
    #   - `hits`: 本塁打を **含む** 安打数（単打・二塁打・三塁打・本塁打の合計）。
    #     方向別の打率計算 (hits / at_bats) で使うため。
    #   そのため、ある方向が本塁打のみのときは `count: 0, hits: 1, home_run: 1`
    #   になり得る。フロントで `count < hits` を検知しても異常ではない。
    def call
      dir_categories = aggregate_direction_categories
      dir_stats = aggregate_direction_stats

      {
        directions: build_directions(dir_categories, dir_stats),
        home_runs: build_home_runs(dir_categories)
      }
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

    # 方向別の打数 / 安打 / 長打打数を集計する。
    # plate_results.counted_in_at_bats を SSoT として打数を導出するため joins(:plate_result) で結合する。
    def aggregate_direction_stats
      base = filtered_scope
      direction_sql = build_direction_sql
      cross = base
              .joins(:plate_result)
              .where("#{direction_sql} IS NOT NULL AND #{direction_sql} > 0")
              .group(Arel.sql(direction_sql), :plate_result_id, 'plate_results.counted_in_at_bats')
              .count

      dir_stats = Hash.new do |h, k|
        h[k] = { at_bats: 0, hits: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0, total_bases: 0 }
      end
      cross.each do |(dir_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        bucket = dir_stats[dir_id]
        bucket[:at_bats] += cnt if counted
        next unless HIT_RESULT_IDS.include?(result_id)

        bucket[:hits] += cnt
        bucket[:total_bases] += cnt * TOTAL_BASES_PER_RESULT.fetch(result_id, 0)
        bucket[:two_base_hit] += cnt if result_id == TWO_BASE_RESULT_ID
        bucket[:three_base_hit] += cnt if result_id == THREE_BASE_RESULT_ID
        bucket[:home_run] += cnt if result_id == HR_RESULT_ID
      end
      dir_stats
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

    def build_directions(dir_categories, dir_stats)
      DIRECTION_LABELS.map do |id, label|
        cats = dir_categories[id]
        non_hr = cats.except('本塁打')
        total = non_hr.values.sum
        top_category = non_hr.max_by { |_, v| v }&.first || 'その他'
        stats = dir_stats[id]
        {
          id:,
          label:,
          count: total,
          top_category:,
          at_bats: stats[:at_bats],
          hits: stats[:hits],
          two_base_hit: stats[:two_base_hit],
          three_base_hit: stats[:three_base_hit],
          home_run: stats[:home_run],
          total_bases: stats[:total_bases]
        }
      end
    end

    def build_home_runs(dir_categories)
      DIRECTION_LABELS.filter_map do |id, label|
        count = dir_categories[id]['本塁打']
        next if count.zero?

        { id:, label:, count: }
      end
    end

    # call 内で aggregate_direction_categories / aggregate_direction_stats から
    # 2 回参照されるため、同一インスタンス内では scope 構築を再利用する。
    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

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
