module Stats
  # game_result 単位で batting_average レコードを再集計するサービス。
  #
  # 「新仕様試合」（is_new_format = true の plate_appearance が1件以上ある試合）のみを対象とする。
  # 旧仕様試合（v1 で作成された既存試合）の batting_average は触らない。
  #
  # 計算ロジックは plate_result_id ベースで、mobile/constants/battingData.ts:109-162
  # computeBattingStats と整合する結果になるよう設計されている（plate_results.counted_in_at_bats
  # フラグおよび plate_result_id == 7,8,9,10 のヒット種別判定）。
  class BattingAverageRecalculator
    HIT_RESULT_IDS = [7, 8, 9, 10].freeze
    SINGLE_HIT_ID = 7
    DOUBLE_HIT_ID = 8
    TRIPLE_HIT_ID = 9
    HOME_RUN_ID = 10
    SACRIFICE_HIT_ID = 11
    SACRIFICE_FLY_ID = 12
    STRIKE_OUT_IDS = [13, 14].freeze
    BASE_ON_BALLS_ID = 15
    HIT_BY_PITCH_ID = 16
    ERROR_ID = 5

    # @param game_result_id [Integer]
    def initialize(game_result_id:)
      @game_result_id = game_result_id
    end

    # 対象試合が新仕様試合なら batting_average を再集計して保存する。
    # 旧仕様試合の場合は何もしない（既存集計値を保持）。
    #
    # @return [BattingAverage, nil] 更新後のレコード。旧仕様試合の場合は nil
    def call
      return nil unless new_format_game?

      batting_average = BattingAverage.find_or_initialize_by(game_result_id: @game_result_id)
      batting_average.user_id ||= GameResult.find(@game_result_id).user_id
      batting_average.assign_attributes(aggregate_stats)
      batting_average.save!
      batting_average
    end

    private

    # is_new_format フラグが立った打席が1件でもあれば新仕様試合
    def new_format_game?
      PlateAppearance.exists?(game_result_id: @game_result_id, is_new_format: true)
    end

    # 全カラム一気に組み立てる都合上 ABC が高くなるが、各行は独立した集計式で複雑度は低いため許容する。
    def aggregate_stats # rubocop:disable Metrics/AbcSize
      scope = PlateAppearance.where(game_result_id: @game_result_id)
      with_plate_result = scope.joins(:plate_result)

      {
        plate_appearances: scope.count,
        times_at_bat: with_plate_result.where(plate_results: { counted_in_at_bats: true }).count,
        at_bats: with_plate_result.where(plate_results: { counted_in_at_bats: true }).count,
        hit: scope.where(plate_result_id: HIT_RESULT_IDS).count,
        two_base_hit: scope.where(plate_result_id: DOUBLE_HIT_ID).count,
        three_base_hit: scope.where(plate_result_id: TRIPLE_HIT_ID).count,
        home_run: scope.where(plate_result_id: HOME_RUN_ID).count,
        total_bases: compute_total_bases(scope),
        runs_batted_in: scope.sum(:rbi).to_i,
        run: scope.sum(:run_scored).to_i,
        strike_out: scope.where(plate_result_id: STRIKE_OUT_IDS).count,
        base_on_balls: scope.where(plate_result_id: BASE_ON_BALLS_ID).count,
        hit_by_pitch: scope.where(plate_result_id: HIT_BY_PITCH_ID).count,
        sacrifice_hit: scope.where(plate_result_id: SACRIFICE_HIT_ID).count,
        sacrifice_fly: scope.where(plate_result_id: SACRIFICE_FLY_ID).count,
        stealing_base: scope.sum(:stolen_bases).to_i,
        caught_stealing: scope.sum(:caught_stealing).to_i,
        error: scope.where(plate_result_id: ERROR_ID).count
      }
    end

    def compute_total_bases(scope)
      scope.where(plate_result_id: SINGLE_HIT_ID).count +
        (scope.where(plate_result_id: DOUBLE_HIT_ID).count * 2) +
        (scope.where(plate_result_id: TRIPLE_HIT_ID).count * 3) +
        (scope.where(plate_result_id: HOME_RUN_ID).count * 4)
    end
  end
end
