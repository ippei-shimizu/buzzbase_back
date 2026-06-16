# frozen_string_literal: true

module Stats
  # 球種（pitch_types マスタ）別の打席集計サービス。
  #
  # pitch_type_id が記録された新仕様 PA を対象に、マスタ display_order 順で
  # plate_appearances / at_bats / hits / total_bases / 各内訳 / 打率 / OBP /
  # SLG / OPS / result_counts を返す。母数 0 でも全 10 行（マスタ全件）を
  # 出してフロント側で安定して描画できるようにする。
  #
  # mobile 側の球種別カードでは「得意 / 苦手」ハイライト表示の上、
  # 行タップで PitcherFaceoffList と同じ詳細グリッドを展開する。
  class PitchTypeAggregator
    Recalc = ::Stats::BattingAverageRecalculator
    HIT_RESULT_IDS = Recalc::HIT_RESULT_IDS
    TOTAL_BASES_BY_RESULT_ID = {
      Recalc::SINGLE_HIT_ID => 1,
      Recalc::DOUBLE_HIT_ID => 2,
      Recalc::TRIPLE_HIT_ID => 3,
      Recalc::HOME_RUN_ID => 4
    }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] rows: [{ id, label, plate_appearances, at_bats, hits,
    #   total_bases, base_on_balls, hit_by_pitch, sacrifice_fly,
    #   batting_average, on_base_percentage, slugging_percentage, ops,
    #   result_counts: [{plate_result_id, plate_result_name, count}] }],
    #   total_target_pa: 対象打席数
    def call
      stats_by_pitch_type = aggregate_stats
      total_target_pa = filtered_scope.where.not(pitch_type_id: nil).count
      plate_result_names_by_id = PlateResult.pluck(:id, :name).to_h

      rows = PitchType.order(:display_order).map do |pt|
        build_row(pt, stats_by_pitch_type[pt.id] || empty_bucket, plate_result_names_by_id)
      end

      { rows:, total_target_pa: }
    end

    private

    def build_row(pitch_type, stats, plate_result_names_by_id)
      at_bats = stats[:at_bats]
      hits = stats[:hits]
      bb = stats[:base_on_balls]
      hbp = stats[:hit_by_pitch]
      sf = stats[:sacrifice_fly]
      total_bases = stats[:total_bases]
      obp = safe_divide(hits + bb + hbp, at_bats + bb + hbp + sf)
      slg = safe_divide(total_bases, at_bats)
      {
        id: pitch_type.id,
        label: pitch_type.name,
        plate_appearances: stats[:plate_appearances],
        at_bats:,
        hits:,
        total_bases:,
        base_on_balls: bb,
        hit_by_pitch: hbp,
        sacrifice_fly: sf,
        batting_average: safe_divide(hits, at_bats),
        on_base_percentage: obp,
        slugging_percentage: slg,
        ops: (obp + slg).round(3),
        result_counts: build_result_counts(stats[:result_counts], plate_result_names_by_id)
      }
    end

    def build_result_counts(counts, plate_result_names_by_id)
      counts.sort_by { |id, _| id }.map do |id, count|
        {
          plate_result_id: id,
          plate_result_name: plate_result_names_by_id[id] || '',
          count:
        }
      end
    end

    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .where.not(pitch_type_id: nil)
                            .group(:pitch_type_id, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = empty_bucket }
      cross.each do |(pitch_type_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        accumulate_into(stats[pitch_type_id], result_id, counted, cnt)
      end
      stats
    end

    def accumulate_into(bucket, result_id, counted, cnt)
      bucket[:plate_appearances] += cnt
      bucket[:at_bats] += cnt if counted
      bucket[:hits] += cnt if HIT_RESULT_IDS.include?(result_id)
      bucket[:total_bases] += (TOTAL_BASES_BY_RESULT_ID[result_id] || 0) * cnt
      bucket[:base_on_balls] += cnt if result_id == Recalc::BASE_ON_BALLS_ID
      bucket[:hit_by_pitch] += cnt if result_id == Recalc::HIT_BY_PITCH_ID
      bucket[:sacrifice_fly] += cnt if result_id == Recalc::SACRIFICE_FLY_ID
      bucket[:result_counts][result_id] = bucket[:result_counts].fetch(result_id, 0) + cnt
    end

    def empty_bucket
      {
        plate_appearances: 0, at_bats: 0, hits: 0,
        total_bases: 0, base_on_balls: 0, hit_by_pitch: 0, sacrifice_fly: 0,
        result_counts: {}
      }
    end

    def safe_divide(numerator, denominator)
      return 0.0 if denominator.to_i.zero?

      (numerator.to_f / denominator).round(3)
    end

    # aggregate_stats が joins(:plate_result) を使うため、ここでも
    # plate_result_id IS NULL の PA を弾いておく。これにより
    # total_target_pa（このスコープに対する .count）と aggregate_stats の
    # 母数が必ず一致する（行合計 == total_target_pa を保証）。
    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
                               .where.not(plate_result_id: nil)
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
