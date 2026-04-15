# frozen_string_literal: true

module Stats
  class PitchingStatsTableService
    include Concerns::TableServiceConcern

    INNINGS_PER_GAME = 9

    PITCHING_FIELDS = %w[
      win loss hold saves complete_games shutouts innings_pitched
      hits_allowed home_runs_hit strikeouts base_on_balls hit_by_pitch run_allowed earned_run
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
      years = scope.select(Arel.sql('DISTINCT EXTRACT(YEAR FROM match_results.date_and_time)::int AS yr'))
                   .filter_map(&:yr).sort

      rows = years.map { |year| build_row(label: year.to_s, scope: scope_for_year(scope, year)) }
      rows << build_row(label: '通算', scope:) if rows.size > 1
      rows
    end

    # --- monthly ---
    def monthly_rows
      scope = @year.present? ? scope_for_year(base_scope, @year.to_i) : base_scope
      months = scope.select(Arel.sql('DISTINCT EXTRACT(MONTH FROM match_results.date_and_time)::int AS mon'))
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
        row = compose_row(mr.date_and_time.strftime('%m/%d'), extract_pitching_stats(pr))
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

    def extract_pitching_stats(pitching_result)
      {
        'appearances' => 1,
        'win' => pitching_result.win.to_i,
        'loss' => pitching_result.loss.to_i,
        'hold' => pitching_result.hold.to_i,
        'saves' => pitching_result.saves.to_i,
        'complete_games' => pitching_result.got_to_the_distance ? 1 : 0,
        'shutouts' => pitching_result.got_to_the_distance && pitching_result.run_allowed.to_i.zero? ? 1 : 0,
        'innings_pitched' => pitching_result.innings_pitched.to_f,
        'hits_allowed' => pitching_result.hits_allowed.to_i,
        'home_runs_hit' => pitching_result.home_runs_hit.to_i,
        'strikeouts' => pitching_result.strikeouts.to_i,
        'base_on_balls' => pitching_result.base_on_balls.to_i,
        'hit_by_pitch' => pitching_result.hit_by_pitch.to_i,
        'run_allowed' => pitching_result.run_allowed.to_i,
        'earned_run' => pitching_result.earned_run.to_i
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

    def calculate_pitching_rate_values(innings, strikeouts, walks, stats)
      {
        era: safe_divide(stats['earned_run'].to_f * INNINGS_PER_GAME, innings, 2),
        whip: safe_divide(walks.to_f + stats['hits_allowed'].to_f, innings),
        k_per_nine: safe_divide(strikeouts.to_f * 9, innings),
        bb_per_nine: safe_divide(walks.to_f * 9, innings),
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
        'SUM(win) AS win',
        'SUM(loss) AS loss',
        'SUM(hold) AS hold',
        'SUM(saves) AS saves',
        'SUM(CASE WHEN got_to_the_distance THEN 1 ELSE 0 END) AS complete_games',
        'SUM(CASE WHEN got_to_the_distance = true AND run_allowed = 0 THEN 1 ELSE 0 END) AS shutouts',
        'ROUND(SUM(innings_pitched)::numeric, 1) AS innings_pitched',
        'SUM(hits_allowed) AS hits_allowed',
        'SUM(home_runs_hit) AS home_runs_hit',
        'SUM(strikeouts) AS strikeouts',
        'SUM(base_on_balls) AS base_on_balls',
        'SUM(hit_by_pitch) AS hit_by_pitch',
        'SUM(run_allowed) AS run_allowed',
        'SUM(earned_run) AS earned_run'
      ]
    end
  end
end
