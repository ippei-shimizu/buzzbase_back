# frozen_string_literal: true

module Stats
  # 球種 × 投球コースのクロス集計サービス。
  #
  # pitch_course と pitch_type_id の両方が記録された新仕様 PA を対象に、
  # 球種（マスタ display_order 順）ごとに 25 セルの zones を返す。
  # 最大 250 セルと大きいため、クライアント側は「球種別」タブを開いたときのみ
  # 取得する想定（常時取得しない）。
  class PitchCoursePitchTypeAggregator
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

    # @return [Hash] rows: マスタ全球種分 [{ id, label, plate_appearances,
    #   zones: 必ず 25 要素 }], total_target_pa: 対象打席数,
    #   min_at_bats: is_reliable のしきい値
    def call
      stats = aggregate_stats

      rows = PitchType.order(:display_order).map do |pitch_type|
        zones = PlateAppearance::PITCH_COURSES.map do |course|
          build_zone(course, stats[[pitch_type.id, course]] || empty_zone_bucket)
        end
        {
          id: pitch_type.id,
          label: pitch_type.name,
          plate_appearances: zones.sum { |z| z[:plate_appearances] },
          zones:
        }
      end

      {
        rows:,
        total_target_pa: rows.sum { |r| r[:plate_appearances] },
        min_at_bats: MIN_AT_BATS
      }
    end

    private

    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .group(:pitch_type_id, :pitch_course, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = empty_zone_bucket }
      cross.each do |(pitch_type_id, pitch_course, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        accumulate_zone(stats[[pitch_type_id, pitch_course]], result_id, counted, cnt)
      end
      stats
    end

    # コースと球種の両方が記録された PA のみをクロス集計の母数にする。
    # rows の zones が全コースを網羅するため、合計が filtered_scope.count と必ず一致する。
    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
                               .where.not(plate_result_id: nil)
                               .where.not(pitch_course: nil)
                               .where.not(pitch_type_id: nil)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        scope = apply_tournament_filter(scope)
        apply_date_range_filter(scope)
      end
    end
  end
end
