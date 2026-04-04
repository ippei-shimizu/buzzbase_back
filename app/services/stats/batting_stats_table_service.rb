# frozen_string_literal: true

module Stats
  class BattingStatsTableService
    include Concerns::TableServiceConcern

    BATTING_FIELDS = %w[
      plate_appearances at_bats hit two_base_hit three_base_hit home_run
      total_bases runs_batted_in run strike_out base_on_balls hit_by_pitch
      sacrifice_hit sacrifice_fly stealing_base caught_stealing error
    ].freeze

    BATTING_SYMBOLS = BATTING_FIELDS.map(&:to_sym).freeze

    # mode: :yearly, :monthly, :daily
    # year: required for :monthly and :daily
    def initialize(user_id:, mode: :yearly, year: nil, season_id: nil)
      @user_id = user_id
      @mode = mode.to_sym
      @year = year
      @season_id = season_id
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
      scope = BattingAverage.joins(game_result: :match_result)
                            .where(batting_averages: { user_id: @user_id })
      scope = scope.where(game_results: { season_id: @season_id }) if @season_id.present?
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
      game_results = scope.includes(game_result: { match_result: :opponent_team })
                          .order('match_results.date_and_time ASC')

      games_prefix = { 'games' => 1 }
      rows = game_results.map do |ba|
        mr = ba.game_result.match_result
        row = compose_row(mr.date_and_time.strftime('%m/%d'), games_prefix.merge(extract_int_stats(ba, BATTING_FIELDS)))
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

    def compose_row(label, stats)
      vals = int_values(stats, BATTING_FIELDS)
      derived = calculate_rate_stats(vals)

      { label:, games: stats['games'].to_i }.merge(vals.transform_keys(&:to_sym)).merge(derived)
    end

    def calculate_rate_stats(vals)
      hit = vals['hit'] + vals['two_base_hit'] + vals['three_base_hit'] + vals['home_run']
      tb = vals['hit'] + (vals['two_base_hit'] * 2) + (vals['three_base_hit'] * 3) + (vals['home_run'] * 4)

      calculate_batting_rates(hit, tb, vals)
    end

    def calculate_batting_rates(hit, total_bases, vals)
      ab = vals['at_bats']
      bb = vals['base_on_balls']

      avg = safe_divide(hit.to_f, ab)
      slg = safe_divide(total_bases.to_f, ab)
      obp = calculate_obp(hit, vals)

      { hit:, total_bases:, batting_average: avg, slugging_percentage: slg,
        ops: (obp + slg).round(3), iso: safe_divide((total_bases - hit).to_f, ab),
        bb_per_k: safe_divide(bb.to_f, vals['strike_out']) }
        .merge(babip: calculate_babip(hit, vals))
    end

    def calculate_obp(hit, vals)
      on_base = hit + vals['base_on_balls'] + vals['hit_by_pitch']
      denom = vals['at_bats'] + vals['base_on_balls'] + vals['hit_by_pitch'] + vals['sacrifice_fly']
      safe_divide(on_base.to_f, denom)
    end

    def calculate_babip(hit, vals)
      numer = hit - vals['home_run']
      denom = vals['at_bats'] - vals['strike_out'] - vals['home_run'] + vals['sacrifice_fly']
      safe_divide(numer.to_f, denom)
    end

    def empty_row(label)
      base = { label:, games: 0 }
      zeros = BATTING_SYMBOLS.index_with { 0 }
      rates = { hit: ZERO, batting_average: ZERO, slugging_percentage: ZERO, ops: ZERO,
                iso: ZERO, bb_per_k: ZERO, babip: ZERO }
      base.merge(zeros).merge(rates)
    end

    def aggregate_columns
      cols = BATTING_FIELDS.map { |f| "SUM(#{f}) AS #{f}" }
      cols.unshift('COUNT(*) AS games')
      cols
    end
  end
end
