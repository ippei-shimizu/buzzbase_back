# frozen_string_literal: true

module Stats
  # 対戦投手 × 投球コースのクロス集計サービス。
  #
  # pitch_course と pitcher_id の両方が記録された新仕様 PA を対象に、
  # 投手ごとに 25 セルの zones を返す。投手数 × 25 セルと大きいため、
  # クライアント側は「投手別」タブを開いたときのみ取得する想定（常時取得しない）。
  class PitcherFaceoffCourseAggregator
    include Concerns::FilterableConcern
    include Concerns::PitchCourseZoneConcern

    # コース付き打席がこの値未満の投手はセレクタに出さない。1 セル 1 打席ばかりの
    # ヒートマップを誤読させないため、PitcherFaceoffAggregator と同じ下限を使う。
    MIN_PLATE_APPEARANCES = PitcherFaceoffAggregator::MIN_PLATE_APPEARANCES

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil, start_month: nil, end_month: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
      @start_month = start_month
      @end_month = end_month
    end

    # @return [Hash] rows: しきい値以上の投手 [{ id, label, team_name,
    #   plate_appearances, zones: 必ず 25 要素 }]（対戦多い順 → 投手名昇順 → id 昇順）,
    #   total_target_pa: コースと投手の両方が記録された打席数（しきい値未満の投手も含む）,
    #   min_at_bats: is_reliable のしきい値, min_plate_appearances: セレクタに出す下限
    def call
      stats = aggregate_stats
      plate_appearances_by_pitcher_id = stats.each_with_object(Hash.new(0)) do |((pitcher_id, _course), bucket), totals|
        totals[pitcher_id] += bucket[:plate_appearances]
      end

      eligible_pitcher_ids = plate_appearances_by_pitcher_id.select { |_, count| count >= MIN_PLATE_APPEARANCES }.keys
      pitchers = Pitcher.where(id: eligible_pitcher_ids).includes(:team)

      rows = pitchers.map { |pitcher| build_row(pitcher, stats) }
      rows.sort_by! { |row| [-row[:plate_appearances], row[:label], row[:id]] }

      {
        rows:,
        total_target_pa: plate_appearances_by_pitcher_id.values.sum,
        min_at_bats: MIN_AT_BATS,
        min_plate_appearances: MIN_PLATE_APPEARANCES
      }
    end

    private

    def build_row(pitcher, stats)
      zones = PlateAppearance::PITCH_COURSES.map do |course|
        build_zone(course, stats.fetch([pitcher.id, course]) { empty_zone_bucket })
      end
      {
        id: pitcher.id,
        label: pitcher.name,
        team_name: pitcher.team&.name,
        plate_appearances: zones.sum { |zone| zone[:plate_appearances] },
        zones:
      }
    end

    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .group(:pitcher_id, :pitch_course, :plate_result_id,
                                   'plate_results.counted_in_at_bats', :swing_type)
                            .count

      stats = Hash.new { |hash, key| hash[key] = empty_zone_bucket }
      cross.each do |(pitcher_id, pitch_course, result_id, counted, swing_type), count| # rubocop:disable Style/HashEachMethods
        accumulate_zone(stats[[pitcher_id, pitch_course]], result_id, counted, swing_type, count)
      end
      stats
    end

    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
                               .where.not(plate_result_id: nil)
                               .where.not(pitch_course: nil)
                               .where.not(pitcher_id: nil)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        scope = apply_tournament_filter(scope)
        apply_date_range_filter(scope)
      end
    end
  end
end
