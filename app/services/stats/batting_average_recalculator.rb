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
    # @param user_id [Integer, nil] batting_average を新規作成する際に使用。
    #   nil の場合は GameResult から逆引きする（追加クエリ発生）。controller では既知の値を渡すのが望ましい。
    # @param cleanup_orphan [Boolean] 新仕様試合でなくなった時に、孤立した batting_average を削除するか。
    #   v2 で新仕様試合の最後の打席を削除した場合に true を指定する（旧仕様試合の batting_average は保護される）。
    def initialize(game_result_id:, user_id: nil, cleanup_orphan: false)
      @game_result_id = game_result_id
      @user_id = user_id
      @cleanup_orphan = cleanup_orphan
    end

    # 対象試合が新仕様試合（全 PA が is_new_format=true）なら batting_average を再集計して保存する。
    # 旧 PA が 1 件でも残っている試合では何もしない（既存集計値を保護）。
    # cleanup_orphan が true かつ PA が完全に 0 件のとき、対応する batting_average を削除する
    # （v2 で新仕様試合の最後の打席を削除した時の孤立レコード対策）。
    # PA に旧 PA が含まれる「混在試合」のケースでは旧フローで直書きされた集計値を
    # 上書きしないよう、cleanup_orphan が true であっても触らない。
    #
    # @return [BattingAverage, nil] 更新後のレコード。再集計しない場合や削除した場合は nil
    def call
      return recalculate_and_save if new_format_game?
      return cleanup_orphaned_batting_average if @cleanup_orphan && plate_appearances_empty?

      nil
    end

    private

    def recalculate_and_save
      batting_average = BattingAverage.find_or_initialize_by(game_result_id: @game_result_id)
      batting_average.user_id ||= resolve_user_id
      batting_average.assign_attributes(aggregate_stats)
      batting_average.save!
      batting_average
    end

    def cleanup_orphaned_batting_average
      BattingAverage.where(game_result_id: @game_result_id).destroy_all
      nil
    end

    def resolve_user_id
      @user_id || GameResult.find(@game_result_id).user_id
    end

    # 「全 PA が is_new_format=true かつ PA が 1 件以上」のときだけ新仕様試合と判定する。
    # 1 件でも旧 PA (is_new_format=false) が含まれる混在試合では false を返し、
    # 旧フローで batting_averages に直書きされた集計値を保護する。
    def new_format_game?
      game_pa_relation = PlateAppearance.where(game_result_id: @game_result_id)
      game_pa_relation.exists? && !game_pa_relation.exists?(is_new_format: false)
    end

    # 試合に紐づく PA が 1 件も無い状態かどうか。
    # cleanup_orphan の発動条件として使う（混在試合や旧仕様試合では false になるため誤発動を防ぐ）。
    def plate_appearances_empty?
      !PlateAppearance.exists?(game_result_id: @game_result_id)
    end

    # 全カラム一気に組み立てる都合上 ABC が高くなるが、各行は独立した集計式で複雑度は低いため許容する。
    def aggregate_stats # rubocop:disable Metrics/AbcSize
      scope = PlateAppearance.where(game_result_id: @game_result_id)
      with_plate_result = scope.joins(:plate_result)
      # times_at_bat と at_bats は野球統計上は別概念（前者は打席数、後者は打数）だが、
      # 本アプリでは既存集計テーブルに揃えて同一値で運用している（旧仕様 batting_average も同様）。
      counted = with_plate_result.where(plate_results: { counted_in_at_bats: true }).count

      {
        plate_appearances: scope.count,
        times_at_bat: counted,
        at_bats: counted,
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
