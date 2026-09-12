# frozen_string_literal: true

module Stats
  # 投球コース（plate_appearances.pitch_course、1〜25）別の打席集計サービス。
  #
  # pitch_course が記録された新仕様 PA を対象に、コースごとの
  # plate_appearances / at_bats / hits / batting_average を返す。
  # 母数 0 のコースも行を落とさず、zones は必ず 25 要素で返して
  # クライアント側でヒートマップを安定して描画できるようにする。
  #
  # 保存値は捕手目線の絶対座標のため、内角/外角のラベル表示は
  # クライアント側で users.batting_side から導出する。
  class PitchCourseAggregator
    include Concerns::FilterableConcern
    include Concerns::PitchCourseZoneConcern

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil, start_month: nil, end_month: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
      @start_month = start_month
      @end_month = end_month
    end

    # @return [Hash] zones: 必ず 25 要素 [{ course, row, col, is_strike_zone,
    #   plate_appearances, at_bats, hits, batting_average, is_reliable }],
    #   strike_zone / ball_zone: ゾーン単位の集計,
    #   total_target_pa: 対象打席数, min_at_bats: is_reliable のしきい値
    def call
      stats_by_course = aggregate_stats
      zones = PlateAppearance::PITCH_COURSES.map do |course|
        build_zone(course, stats_by_course[course] || empty_zone_bucket)
      end

      {
        zones:,
        strike_zone: zone_summary(zones.select { |z| z[:is_strike_zone] }),
        ball_zone: zone_summary(zones.reject { |z| z[:is_strike_zone] }),
        # zones が全コースを網羅しているため、合計が filtered_scope.count と必ず一致する。
        total_target_pa: zones.sum { |z| z[:plate_appearances] },
        min_at_bats: MIN_AT_BATS
      }
    end

    private

    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .group(:pitch_course, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = empty_zone_bucket }
      cross.each do |(pitch_course, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        accumulate_zone(stats[pitch_course], result_id, counted, cnt)
      end
      stats
    end

    # aggregate_stats が joins(:plate_result) を使うため plate_result_id IS NULL を弾き、
    # total_target_pa と集計母数を必ず一致させる（PitchTypeAggregator と同じ判断）。
    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
                               .where.not(plate_result_id: nil)
                               .where.not(pitch_course: nil)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        scope = apply_tournament_filter(scope)
        apply_date_range_filter(scope)
      end
    end
  end
end
