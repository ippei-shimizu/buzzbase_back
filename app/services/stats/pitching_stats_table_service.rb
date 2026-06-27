# frozen_string_literal: true

module Stats
  class PitchingStatsTableService # rubocop:disable Metrics/ClassLength
    include Concerns::TableServiceConcern

    PITCHING_FIELDS = %w[
      win loss hold saves complete_games shutouts innings_pitched
      hits_allowed home_runs_hit strikeouts base_on_balls hit_by_pitch run_allowed earned_run number_of_pitches
    ].freeze

    PITCHING_SYMBOLS = PITCHING_FIELDS.map(&:to_sym).freeze

    # mode: :yearly, :monthly, :daily
    # year: required for :monthly and :daily
    def initialize(user_id:, mode: :yearly, year: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @mode = mode.to_sym
      @year = year
      @season_id = season_id
      @tournament_id = tournament_id
    end

    def call
      case @mode
      when :yearly then yearly_rows
      when :monthly then monthly_rows
      when :daily then daily_rows
      else raise ArgumentError, "Unknown mode: #{@mode}"
      end
    end

    private

    def base_scope
      scope = PitchingResult.joins(game_result: :match_result)
                            .where(pitching_results: { user_id: @user_id })
                            .where('pitching_results.innings_pitched > 0')
      scope = scope.where(game_results: { season_id: @season_id }) if @season_id.present?
      scope = scope.where(match_results: { tournament_id: @tournament_id }) if @tournament_id.present?
      scope
    end

    # --- yearly ---
    def yearly_rows
      scope = base_scope
      years = scope.select(Arel.sql("DISTINCT #{Stats::JstDateSql::YEAR_JST_INT_SQL} AS yr"))
                   .filter_map(&:yr).sort

      rows = years.map { |year| build_row(label: year.to_s, scope: scope_for_year(scope, year)) }
      rows << build_row(label: '通算', scope:) if rows.size > 1
      rows
    end

    # --- monthly ---
    def monthly_rows
      scope = @year.present? ? scope_for_year(base_scope, @year.to_i) : base_scope
      months = scope.select(Arel.sql("DISTINCT #{Stats::JstDateSql::MONTH_JST_INT_SQL} AS mon"))
                    .filter_map(&:mon).sort

      rows = months.map { |mon| build_row(label: "#{mon}月", scope: scope_for_month(scope, mon)) }
      rows << build_row(label: '通算', scope:) if rows.size > 1
      rows
    end

    # --- daily ---
    def daily_rows
      scope = @year.present? ? scope_for_year(base_scope, @year.to_i) : base_scope
      records = scope.includes(game_result: { match_result: :opponent_team })
                     .order('match_results.date_and_time ASC')

      rows = records.map do |pr|
        mr = pr.game_result.match_result
        row = compose_row(mr.date_and_time.strftime('%m/%d'), extract_pitching_stats(pr, mr.inning_format))
        row[:opponent] = mr.opponent_team&.name || '不明'
        row
      end

      rows << build_row(label: '通算', scope:) if rows.size > 1
      rows
    end

    # --- helpers ---
    def build_row(label:, scope:)
      agg = scope.select(aggregate_columns).reorder(nil).take
      return empty_row(label) unless agg

      compose_row(label, agg.attributes)
    end

    # @param pitching_result [PitchingResult]
    # @param inning_format [Integer] 当該試合のイニング制（7 or 9）
    # @return [Hash{String=>Numeric}] 個別行のスタッツ。
    #   weighted_* は集計クエリの加重和カラムと整合させるため、当該試合の inning_format を係数として掛ける。
    def extract_pitching_stats(pitching_result, inning_format)
      base_pitching_stats(pitching_result)
        .merge(weighted_pitching_stats(pitching_result, inning_format))
    end

    def base_pitching_stats(record) # rubocop:disable Metrics/AbcSize
      {
        'appearances' => 1,
        'win' => record.win.to_i,
        'loss' => record.loss.to_i,
        'hold' => record.hold.to_i,
        'saves' => record.saves.to_i,
        'complete_games' => record.got_to_the_distance ? 1 : 0,
        'shutouts' => record.got_to_the_distance && record.run_allowed.to_i.zero? ? 1 : 0,
        'innings_pitched' => record.innings_pitched.to_f,
        'hits_allowed' => record.hits_allowed.to_i,
        'home_runs_hit' => record.home_runs_hit.to_i,
        'strikeouts' => record.strikeouts.to_i,
        'base_on_balls' => record.base_on_balls.to_i,
        'hit_by_pitch' => record.hit_by_pitch.to_i,
        'run_allowed' => record.run_allowed.to_i,
        'earned_run' => record.earned_run.to_i,
        'number_of_pitches' => record.number_of_pitches.to_i
      }
    end

    def weighted_pitching_stats(record, inning_format)
      {
        'weighted_earned_run' => record.earned_run.to_i * inning_format,
        'weighted_strikeouts' => record.strikeouts.to_i * inning_format,
        'weighted_base_on_balls' => record.base_on_balls.to_i * inning_format
      }
    end

    def compose_row(label, stats)
      base = build_base_pitching_row(label, stats)
      base.merge(calculate_pitching_rates(stats))
    end

    def build_base_pitching_row(label, stats)
      row = { label:, appearances: stats['appearances'].to_i }
      PITCHING_SYMBOLS.each { |field| row[field] = stats[field.to_s].to_i }
      row[:innings_pitched] = stats['innings_pitched'].to_f.round(1)
      row
    end

    def calculate_pitching_rates(stats)
      innings = stats['innings_pitched'].to_f
      strikeouts = stats['strikeouts'].to_i
      walks = stats['base_on_balls'].to_i

      calculate_pitching_rate_values(innings, strikeouts, walks, stats)
    end

    # ERA / K9 / BB9 は試合ごとのイニング制（match_results.inning_format）で加重した分子を投球回で割る。
    # 集計クエリでは aggregate_columns に weighted_* を追加し、個別行（daily）では
    # extract_pitching_stats で当該試合の inning_format を掛けた値を渡す。
    def calculate_pitching_rate_values(innings, strikeouts, walks, stats)
      {
        era: safe_divide(stats['weighted_earned_run'].to_f, innings, 2),
        whip: safe_divide(walks.to_f + stats['hits_allowed'].to_f, innings),
        k_per_nine: safe_divide(stats['weighted_strikeouts'].to_f, innings),
        bb_per_nine: safe_divide(stats['weighted_base_on_balls'].to_f, innings),
        k_bb: safe_divide(strikeouts.to_f, walks),
        win_percentage: safe_divide(stats['win'].to_f, stats['win'].to_i + stats['loss'].to_i)
      }
    end

    def empty_row(label)
      base = { label:, appearances: 0 }
      zeros = PITCHING_SYMBOLS.index_with { 0 }
      zeros[:innings_pitched] = 0.0
      rates = { era: ZERO, whip: ZERO, k_per_nine: ZERO, bb_per_nine: ZERO,
                k_bb: ZERO, win_percentage: ZERO }
      base.merge(zeros).merge(rates)
    end

    def aggregate_columns
      [
        'COUNT(*) AS appearances',
        'SUM(pitching_results.win) AS win',
        'SUM(pitching_results.loss) AS loss',
        'SUM(pitching_results.hold) AS hold',
        'SUM(pitching_results.saves) AS saves',
        'SUM(CASE WHEN pitching_results.got_to_the_distance THEN 1 ELSE 0 END) AS complete_games',
        'SUM(CASE WHEN pitching_results.got_to_the_distance = true AND pitching_results.run_allowed = 0 THEN 1 ELSE 0 END) AS shutouts',
        'ROUND(SUM(pitching_results.innings_pitched)::numeric, 1) AS innings_pitched',
        'SUM(pitching_results.hits_allowed) AS hits_allowed',
        'SUM(pitching_results.home_runs_hit) AS home_runs_hit',
        'SUM(pitching_results.strikeouts) AS strikeouts',
        'SUM(pitching_results.base_on_balls) AS base_on_balls',
        'SUM(pitching_results.hit_by_pitch) AS hit_by_pitch',
        'SUM(pitching_results.run_allowed) AS run_allowed',
        'SUM(pitching_results.earned_run) AS earned_run',
        'SUM(pitching_results.number_of_pitches) AS number_of_pitches',
        'SUM(pitching_results.earned_run * match_results.inning_format) AS weighted_earned_run',
        'SUM(pitching_results.strikeouts * match_results.inning_format) AS weighted_strikeouts',
        'SUM(pitching_results.base_on_balls * match_results.inning_format) AS weighted_base_on_balls'
      ]
    end
  end
end
