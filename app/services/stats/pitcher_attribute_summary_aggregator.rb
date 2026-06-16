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
  # マスタが nil の投手は key: nil の「未設定」バケットに集約し、
  # mobile 側で末尾に表示する。
  class PitcherAttributeSummaryAggregator
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS

    # フロントの「投手タイプ別 > 利き手」セクションは、自分の打者目線で
    # 「対◯投」と読める表記に揃える。
    THROW_HAND_LABELS = { 'right' => '対右投', 'left' => '対左投' }.freeze
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
    #   各要素: { key, label, plate_appearances, at_bats, hits, batting_average, display_order }
    def call
      stats_by_pitcher = aggregate_per_pitcher
      pitcher_attrs = load_pitcher_attrs(stats_by_pitcher.keys)
      arm_angles = ArmAngle.pluck(:id, :name, :display_order).index_by(&:first)
      velocity_zones = VelocityZone.pluck(:id, :name, :display_order).index_by(&:first)
      pitcher_styles = PitcherStyle.pluck(:id, :name, :display_order).index_by(&:first)

      {
        by_throw_hand: group_by_throw_hand(stats_by_pitcher, pitcher_attrs),
        by_arm_angle: group_by_master(stats_by_pitcher, pitcher_attrs, :arm_angle_id, arm_angles),
        by_velocity_zone: group_by_master(stats_by_pitcher, pitcher_attrs, :velocity_zone_id, velocity_zones),
        by_pitcher_style: group_by_master(stats_by_pitcher, pitcher_attrs, :pitcher_style_id, pitcher_styles)
      }
    end

    private

    # PitcherFaceoffAggregator と同形の group(:pitcher_id, ...).count を、
    # 投手単位に畳む。
    def aggregate_per_pitcher
      cross = filtered_scope.joins(:plate_result)
                            .where.not(pitcher_id: nil)
                            .group(:pitcher_id, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      stats = Hash.new { |h, k| h[k] = { plate_appearances: 0, at_bats: 0, hits: 0 } }
      cross.each do |(pitcher_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        bucket = stats[pitcher_id]
        bucket[:plate_appearances] += cnt
        bucket[:at_bats] += cnt if counted
        bucket[:hits] += cnt if HIT_RESULT_IDS.include?(result_id)
      end
      stats
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

    def group_by_throw_hand(stats_by_pitcher, pitcher_attrs)
      buckets = Hash.new { |h, k| h[k] = empty_bucket }
      stats_by_pitcher.each do |pitcher_id, s|
        key = pitcher_attrs.dig(pitcher_id, :throw_hand)
        merge_into(buckets[key], s)
      end
      finalize_throw_hand_rows(buckets)
    end

    def group_by_master(stats_by_pitcher, pitcher_attrs, attr_key, master_index)
      buckets = Hash.new { |h, k| h[k] = empty_bucket }
      stats_by_pitcher.each do |pitcher_id, s|
        key = pitcher_attrs.dig(pitcher_id, attr_key)
        merge_into(buckets[key], s)
      end
      finalize_master_rows(buckets, master_index)
    end

    def finalize_throw_hand_rows(buckets)
      rows = buckets.map do |key, bucket|
        label = key.nil? ? UNSET_LABEL : (THROW_HAND_LABELS[key] || key.to_s)
        display_order = display_order_for_throw_hand(key)
        build_bucket_row(key:, label:, display_order:, bucket:)
      end
      rows.sort_by { |row| [row[:display_order], row[:label]] }
    end

    def finalize_master_rows(buckets, master_index)
      rows = buckets.map do |key, bucket|
        if key.nil?
          build_bucket_row(key: nil, label: UNSET_LABEL, display_order: UNSET_DISPLAY_ORDER, bucket:)
        else
          _, name, display_order = master_index[key]
          build_bucket_row(key:, label: name || UNSET_LABEL, display_order: display_order || UNSET_DISPLAY_ORDER, bucket:)
        end
      end
      rows.sort_by { |row| [row[:display_order], row[:label]] }
    end

    def build_bucket_row(key:, label:, display_order:, bucket:)
      {
        key:,
        label:,
        plate_appearances: bucket[:plate_appearances],
        at_bats: bucket[:at_bats],
        hits: bucket[:hits],
        batting_average: safe_divide(bucket[:hits], bucket[:at_bats]),
        display_order:
      }
    end

    def merge_into(bucket, stats)
      bucket[:plate_appearances] += stats[:plate_appearances]
      bucket[:at_bats] += stats[:at_bats]
      bucket[:hits] += stats[:hits]
    end

    def empty_bucket
      { plate_appearances: 0, at_bats: 0, hits: 0 }
    end

    # right=0 / left=1 の enum 順を保ちつつ、未設定は末尾に回す。
    def display_order_for_throw_hand(key)
      return UNSET_DISPLAY_ORDER if key.nil?

      Pitcher.throw_hands[key] || UNSET_DISPLAY_ORDER
    end

    def safe_divide(numerator, denominator)
      return 0.0 if denominator.to_i.zero?

      (numerator.to_f / denominator).round(3)
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
