# frozen_string_literal: true

module Stats
  # 対戦投手の属性別（利き手 / 腕の角度 / 球速帯 / 投手タイプ）に
  # 打席を束ねて打率を返す Aggregator。
  #
  # PitcherFaceoffAggregator が 1 投手単位で集計するのに対し、こちらは
  # 「左投相手は打ててる / オーバーハンドが苦手」といったマクロ傾向を
  # 可視化することを目的とする。同じ filter / scope（新仕様 PA かつ
  # pitcher_id 付き）を踏襲し、属性ごとに plate_appearances / at_bats /
  # hits / batting_average を集計する。
  #
  # 各バケットは PitcherFaceoffAggregator の 1 行と同じスタッツ
  # （total_bases / BB / HBP / SF / OBP / SLG / OPS / result_counts）も
  # 返すので、mobile 側でチップタップ展開時に同じ詳細グリッドを使える。
  #
  # マスタが nil の投手は key: nil の「未設定」バケットに集約し、
  # mobile 側で末尾に表示する。
  class PitcherAttributeSummaryAggregator # rubocop:disable Metrics/ClassLength
    include Concerns::FilterableConcern

    Recalc = ::Stats::BattingAverageRecalculator
    HIT_RESULT_IDS = Recalc::HIT_RESULT_IDS
    TOTAL_BASES_BY_RESULT_ID = {
      Recalc::SINGLE_HIT_ID => 1,
      Recalc::DOUBLE_HIT_ID => 2,
      Recalc::TRIPLE_HIT_ID => 3,
      Recalc::HOME_RUN_ID => 4
    }.freeze

    THROW_HAND_LABELS = { 'right' => '対右投', 'left' => '対左投' }.freeze
    # 利き手の並び順は「右投 → 左投」固定。Pitcher.throw_hands の enum 整数値
    # と一致するが、enum 定義順が将来変わってもこちら側のソート意図が動かない
    # よう定数で明示する。
    THROW_HAND_ORDER = { 'right' => 0, 'left' => 1 }.freeze
    UNSET_LABEL = '未設定'
    UNSET_DISPLAY_ORDER = Float::INFINITY

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] by_throw_hand / by_arm_angle / by_velocity_zone / by_pitcher_style の 4 配列。
    #   各要素: { key, label, plate_appearances, at_bats, hits, total_bases,
    #             base_on_balls, hit_by_pitch, sacrifice_fly, batting_average,
    #             on_base_percentage, slugging_percentage, ops,
    #             result_counts: [{plate_result_id, plate_result_name, count}],
    #             display_order }
    def call
      stats_by_pitcher = aggregate_per_pitcher
      pitcher_attrs = load_pitcher_attrs(stats_by_pitcher.keys)
      arm_angles = ArmAngle.pluck(:id, :name, :display_order).index_by(&:first)
      velocity_zones = VelocityZone.pluck(:id, :name, :display_order).index_by(&:first)
      pitcher_styles = PitcherStyle.pluck(:id, :name, :display_order).index_by(&:first)
      plate_result_names_by_id = PlateResult.pluck(:id, :name).to_h

      ctx = { plate_result_names_by_id: }

      {
        by_throw_hand: group_by_throw_hand(stats_by_pitcher, pitcher_attrs, ctx),
        by_arm_angle: group_by_master(stats_by_pitcher, pitcher_attrs, :arm_angle_id, arm_angles, ctx),
        by_velocity_zone: group_by_master(stats_by_pitcher, pitcher_attrs, :velocity_zone_id, velocity_zones, ctx),
        by_pitcher_style: group_by_master(stats_by_pitcher, pitcher_attrs, :pitcher_style_id, pitcher_styles, ctx)
      }
    end

    private

    # PitcherFaceoffAggregator と同形の group(:pitcher_id, ...).count を、
    # 投手単位に畳む。属性別バケットでもタップ展開時に同じ詳細グリッドを
    # 表示するため、PitcherFaceoff と同じスタッツを各 pitcher で集める。
    def aggregate_per_pitcher
      cross = filtered_scope.joins(:plate_result)
                            .where.not(pitcher_id: nil)
                            .group(:pitcher_id, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = empty_bucket }
      cross.each do |(pitcher_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        accumulate_into(stats[pitcher_id], result_id, counted, cnt)
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

    # pitcher_id → 属性 4 種を一括取得する。集計対象の投手数だけ pluck するので
    # AR オブジェクトの生成コストを避ける。
    # `throw_hand` は enum で pluck すると Rails が "right"/"left" の文字列で返す。
    def load_pitcher_attrs(pitcher_ids)
      return {} if pitcher_ids.empty?

      Pitcher.where(id: pitcher_ids)
             .pluck(:id, :throw_hand, :arm_angle_id, :velocity_zone_id, :pitcher_style_id)
             .to_h do |id, throw_hand, arm_angle_id, velocity_zone_id, pitcher_style_id|
        [id, {
          throw_hand:,
          arm_angle_id:,
          velocity_zone_id:,
          pitcher_style_id:
        }]
      end
    end

    def group_by_throw_hand(stats_by_pitcher, pitcher_attrs, ctx)
      buckets = Hash.new { |h, k| h[k] = empty_bucket }
      stats_by_pitcher.each do |pitcher_id, s|
        # 投手レコードが pluck で取れなかった場合（削除済み等）はスキップする。
        # PitcherFaceoffAggregator と同じく、属性 nil のバケットに混入させない。
        attrs = pitcher_attrs[pitcher_id]
        next if attrs.nil?

        merge_into(buckets[attrs[:throw_hand]], s)
      end
      finalize_throw_hand_rows(buckets, ctx)
    end

    def group_by_master(stats_by_pitcher, pitcher_attrs, attr_key, master_index, ctx)
      buckets = Hash.new { |h, k| h[k] = empty_bucket }
      stats_by_pitcher.each do |pitcher_id, s|
        attrs = pitcher_attrs[pitcher_id]
        next if attrs.nil?

        merge_into(buckets[attrs[attr_key]], s)
      end
      finalize_master_rows(buckets, master_index, ctx)
    end

    def finalize_throw_hand_rows(buckets, ctx)
      rows = buckets.map do |key, bucket|
        label = key.nil? ? UNSET_LABEL : (THROW_HAND_LABELS[key] || key.to_s)
        display_order = display_order_for_throw_hand(key)
        build_bucket_row(key:, label:, display_order:, bucket:, ctx:)
      end
      rows.sort_by { |row| [row[:display_order], row[:label]] }
    end

    def finalize_master_rows(buckets, master_index, ctx)
      rows = buckets.map do |key, bucket|
        if key.nil?
          build_bucket_row(key: nil, label: UNSET_LABEL, display_order: UNSET_DISPLAY_ORDER, bucket:, ctx:)
        else
          _, name, display_order = master_index[key]
          build_bucket_row(key:, label: name || UNSET_LABEL,
                           display_order: display_order || UNSET_DISPLAY_ORDER,
                           bucket:, ctx:)
        end
      end
      rows.sort_by { |row| [row[:display_order], row[:label]] }
    end

    def build_bucket_row(key:, label:, display_order:, bucket:, ctx:)
      at_bats = bucket[:at_bats]
      hits = bucket[:hits]
      bb = bucket[:base_on_balls]
      hbp = bucket[:hit_by_pitch]
      sf = bucket[:sacrifice_fly]
      total_bases = bucket[:total_bases]
      obp = safe_divide(hits + bb + hbp, at_bats + bb + hbp + sf)
      slg = safe_divide(total_bases, at_bats)
      {
        key:,
        label:,
        plate_appearances: bucket[:plate_appearances],
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
        result_counts: build_result_counts(bucket[:result_counts], ctx[:plate_result_names_by_id]),
        display_order:
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

    def merge_into(bucket, stats)
      bucket[:plate_appearances] += stats[:plate_appearances]
      bucket[:at_bats] += stats[:at_bats]
      bucket[:hits] += stats[:hits]
      bucket[:total_bases] += stats[:total_bases]
      bucket[:base_on_balls] += stats[:base_on_balls]
      bucket[:hit_by_pitch] += stats[:hit_by_pitch]
      bucket[:sacrifice_fly] += stats[:sacrifice_fly]
      stats[:result_counts].each do |result_id, cnt|
        bucket[:result_counts][result_id] = bucket[:result_counts].fetch(result_id, 0) + cnt
      end
    end

    def empty_bucket
      {
        plate_appearances: 0, at_bats: 0, hits: 0,
        total_bases: 0, base_on_balls: 0, hit_by_pitch: 0, sacrifice_fly: 0,
        result_counts: {}
      }
    end

    def display_order_for_throw_hand(key)
      return UNSET_DISPLAY_ORDER if key.nil?

      THROW_HAND_ORDER[key] || UNSET_DISPLAY_ORDER
    end

    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end
  end
end
