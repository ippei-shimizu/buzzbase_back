module Stats
  # game_result 単位で batting_average レコードを再集計するサービス。
  #
  # 「新仕様試合」（全 plate_appearance が is_new_format=true の試合）のみを対象とする。
  # 旧 PA が 1 件でも含まれる混在試合や旧仕様試合は、旧フローで直書きされた集計値を
  # 保護するため再集計対象外。
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
    # マイグレーション期間中は旧 PA を含む試合が多数になるため、is_new_format=false の
    # 存在チェックを先に評価して 1 クエリで早期 return できるようにする。
    def new_format_game?
      return false if PlateAppearance.exists?(game_result_id: @game_result_id, is_new_format: false)

      PlateAppearance.exists?(game_result_id: @game_result_id)
    end

    # 試合に紐づく PA が 1 件も無い状態かどうか。
    # cleanup_orphan の発動条件として使う（混在試合や旧仕様試合では false になるため誤発動を防ぐ）。
    def plate_appearances_empty?
      !PlateAppearance.exists?(game_result_id: @game_result_id)
    end

    # 集計対象を 1 クエリで取り出す SELECT 句。COUNT(*) FILTER と SUM を 1 度に発行し、
    # 1 試合分の COUNT/SUM を個別に投げていた ~16 クエリを 1 クエリに集約する。
    # plate_result_id が NULL の PA も総打席数・各 SUM に含めるため LEFT JOIN を使う
    # （counted_in_at_bats フィルタは NULL 結合行を自然に除外する）。
    # 補間値は全て本クラスの整数定数のためインジェクションの懸念は無い。
    AGGREGATE_SQL = <<~SQL.squish.freeze
      COUNT(*) AS plate_appearances,
      COUNT(*) FILTER (WHERE plate_results.counted_in_at_bats = TRUE) AS counted,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{SINGLE_HIT_ID}) AS single,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{DOUBLE_HIT_ID}) AS double,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{TRIPLE_HIT_ID}) AS triple,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{HOME_RUN_ID}) AS homer,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id IN (#{STRIKE_OUT_IDS.join(',')})) AS strike_out,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{BASE_ON_BALLS_ID}) AS base_on_balls,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{HIT_BY_PITCH_ID}) AS hit_by_pitch,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{SACRIFICE_HIT_ID}) AS sacrifice_hit,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{SACRIFICE_FLY_ID}) AS sacrifice_fly,
      COUNT(*) FILTER (WHERE plate_appearances.plate_result_id = #{ERROR_ID}) AS error,
      COALESCE(SUM(plate_appearances.rbi), 0) AS runs_batted_in,
      COALESCE(SUM(plate_appearances.run_scored), 0) AS run,
      COALESCE(SUM(plate_appearances.stolen_bases), 0) AS stealing_base,
      COALESCE(SUM(plate_appearances.caught_stealing), 0) AS caught_stealing
    SQL

    AGGREGATE_KEYS = %i[
      plate_appearances counted single double triple homer strike_out base_on_balls
      hit_by_pitch sacrifice_hit sacrifice_fly error runs_batted_in run
      stealing_base caught_stealing
    ].freeze

    # ハッシュ各キーへの代入が多く ABC が高くなるが、各行は単純なルックアップで複雑度は低いため許容する。
    def aggregate_stats # rubocop:disable Metrics/AbcSize
      row = PlateAppearance.where(game_result_id: @game_result_id)
                           .left_joins(:plate_result)
                           .pick(Arel.sql(AGGREGATE_SQL))
      stats = AGGREGATE_KEYS.zip(Array.wrap(row).map(&:to_i)).to_h

      {
        plate_appearances: stats[:plate_appearances],
        # times_at_bat と at_bats は野球統計上は別概念（前者は打席数、後者は打数）だが、
        # 本アプリでは既存集計テーブルに揃えて同一値で運用している（旧仕様 batting_average も同様）。
        times_at_bat: stats[:counted],
        at_bats: stats[:counted],
        # `batting_averages.hit` は本番運用上「単打のみ」を保持する semantics で揃える。
        # 2B/3B/HR は別カラムで内訳として持つため、ここで全安打を入れると
        # マイページ系 (`BattingAverage.stats_for_user` の `SUM(hit + 2B + 3B + HR)`)
        # で二重計上になる。集計の真は SUM(hit) + SUM(2B) + SUM(3B) + SUM(HR)。
        hit: stats[:single],
        two_base_hit: stats[:double],
        three_base_hit: stats[:triple],
        home_run: stats[:homer],
        # 塁打 (TB) = 単打×1 + 2B×2 + 3B×3 + HR×4。
        total_bases: BattingFormulas.total_bases(
          singles: stats[:single], doubles: stats[:double],
          triples: stats[:triple], home_runs: stats[:homer]
        ),
        runs_batted_in: stats[:runs_batted_in],
        run: stats[:run],
        strike_out: stats[:strike_out],
        base_on_balls: stats[:base_on_balls],
        hit_by_pitch: stats[:hit_by_pitch],
        sacrifice_hit: stats[:sacrifice_hit],
        sacrifice_fly: stats[:sacrifice_fly],
        stealing_base: stats[:stealing_base],
        caught_stealing: stats[:caught_stealing],
        error: stats[:error]
      }
    end
  end
end
