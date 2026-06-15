# frozen_string_literal: true

module Stats
  # 対戦投手別の対戦成績集計サービス。
  #
  # pitcher_id が記録された新仕様 PA を対象に、投手別の
  # 対戦数 / at_bats / hits / batting_average / 最頻 plate_result（「主な結果」）を返す。
  # 最低対戦回数 MIN_PLATE_APPEARANCES（3 打席）未満の投手は除外し、
  # 対戦多い順 → 投手名昇順でソートする。
  class PitcherFaceoffAggregator
    HIT_RESULT_IDS = ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS

    # しきい値未満の投手は表示に含めない。サンプルサイズの少ない打率を
    # ランキング表示で誤読しないための下限。
    MIN_PLATE_APPEARANCES = 3

    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] rows: [{ pitcher_id, pitcher_name, plate_appearances,
    #   at_bats, hits, batting_average, top_result }],
    #   total_target_pa: pitcher_id 付き打席の総数,
    #   min_plate_appearances: しきい値
    def call
      stats = aggregate_stats
      total_target_pa = stats.values.sum { |s| s[:plate_appearances] }
      pitchers_by_id = Pitcher.where(id: stats.keys).index_by(&:id)
      # AR オブジェクトを介さず id → name の Hash だけ作る。マスタ件数は少なくても
      # 集計対象投手ごとに 1 名引くだけなので余計なオブジェクト生成を避ける。
      plate_result_names_by_id = PlateResult.pluck(:id, :name).to_h

      rows = stats.filter_map do |pitcher_id, s|
        next if s[:plate_appearances] < MIN_PLATE_APPEARANCES

        pitcher = pitchers_by_id[pitcher_id]
        next if pitcher.nil?

        build_row(pitcher, s, plate_result_names_by_id)
      end

      rows.sort_by! { |row| [-row[:plate_appearances], row[:pitcher_name]] }

      { rows:, total_target_pa:, min_plate_appearances: MIN_PLATE_APPEARANCES }
    end

    private

    def build_row(pitcher, stats, plate_result_names_by_id)
      top_result_id = stats[:result_counts].max_by { |_, c| c }&.first
      top_result_name = plate_result_names_by_id[top_result_id] || ''
      {
        pitcher_id: pitcher.id,
        pitcher_name: pitcher.name,
        plate_appearances: stats[:plate_appearances],
        at_bats: stats[:at_bats],
        hits: stats[:hits],
        batting_average: safe_divide(stats[:hits], stats[:at_bats]),
        top_result: top_result_name
      }
    end

    # group(:pitcher_id, :plate_result_id, counted_in_at_bats).count から
    # pitcher 単位の at_bats / hits / 結果別 count を 1 クエリで導出する。
    def aggregate_stats
      cross = filtered_scope.joins(:plate_result)
                            .where.not(pitcher_id: nil)
                            .group(:pitcher_id, :plate_result_id,
                                   'plate_results.counted_in_at_bats')
                            .count

      # Hash.new のブロックで直接ハッシュリテラルを生成し、result_counts の {}
      # も投手ごとに独立して作られることを明示する（dup の shallow copy で
      # 共有されないかを読み手に考えさせない）。
      stats = Hash.new do |h, k|
        h[k] = { plate_appearances: 0, at_bats: 0, hits: 0, result_counts: {} }
      end
      cross.each do |(pitcher_id, result_id, counted), cnt| # rubocop:disable Style/HashEachMethods
        bucket = stats[pitcher_id]
        bucket[:plate_appearances] += cnt
        bucket[:at_bats] += cnt if counted
        bucket[:hits] += cnt if HIT_RESULT_IDS.include?(result_id)
        bucket[:result_counts][result_id] = bucket[:result_counts].fetch(result_id, 0) + cnt
      end
      stats
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
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                  "#{yr}-01-01 00:00:00", "#{yr + 1}-01-01 00:00:00")
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
