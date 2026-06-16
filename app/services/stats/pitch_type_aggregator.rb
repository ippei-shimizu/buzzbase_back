# frozen_string_literal: true

module Stats
  # 球種（pitch_types マスタ）別の打席集計サービス。
  #
  # pitch_type_id が記録された新仕様 PA を対象に、マスタ display_order 順で
  # at_bats / hits / total_bases / batting_average / slugging_percentage を返す。
  # 母数 0 でも全 10 行（マスタ全件）を出してフロント側で安定して描画できるようにする。
  class PitchTypeAggregator
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS
    TOTAL_BASES_PER_RESULT = { 7 => 1, 8 => 2, 9 => 3, 10 => 4 }.freeze

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] rows: [{ id, label, at_bats, hits, total_bases,
    #   batting_average, slugging_percentage }], total_target_pa: 対象打席数
    def call
      stats_by_pitch_type = aggregate_stats
      total_target_pa = filtered_scope.where.not(pitch_type_id: nil).count

      rows = PitchType.order(:display_order).map do |pt|
        stats = stats_by_pitch_type[pt.id] || zero_stats
        {
          id: pt.id,
          label: pt.name,
          at_bats: stats[:at_bats],
          hits: stats[:hits],
          total_bases: stats[:total_bases],
          batting_average: safe_divide(stats[:hits], stats[:at_bats]),
          slugging_percentage: safe_divide(stats[:total_bases], stats[:at_bats])
        }
      end

      { rows:, total_target_pa: }
    end

    private

    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .where.not(pitch_type_id: nil)
                            .group(:pitch_type_id, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = zero_stats.dup }
      cross.each do |(pitch_type_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        bucket = stats[pitch_type_id]
        bucket[:at_bats] += cnt if counted
        next unless HIT_RESULT_IDS.include?(result_id)

        bucket[:hits] += cnt
        bucket[:total_bases] += cnt * TOTAL_BASES_PER_RESULT.fetch(result_id, 0)
      end
      stats
    end

    def zero_stats
      { at_bats: 0, hits: 0, total_bases: 0 }
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
