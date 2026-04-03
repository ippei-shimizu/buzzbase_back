# frozen_string_literal: true

module Stats
  class BattingStatsTableService
    ZERO = 0

    # mode: :yearly, :monthly, :daily
    # year: required for :monthly and :daily
    def initialize(user_id:, mode: :yearly, year: nil)
      @user_id = user_id
      @mode = mode.to_sym
      @year = year
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
      BattingAverage.joins(game_result: :match_result)
                    .where(batting_averages: { user_id: @user_id })
    end

    # --- yearly ---
    def yearly_rows
      scope = base_scope
      years = scope.select(Arel.sql("DISTINCT EXTRACT(YEAR FROM match_results.date_and_time)::int AS yr"))
                   .map(&:yr).compact.sort

      rows = years.map { |yr| build_row(label: yr.to_s, scope: scope_for_year(scope, yr)) }
      rows << build_row(label: '通算', scope: scope) if rows.size > 1
      rows
    end

    # --- monthly ---
    def monthly_rows
      raise ArgumentError, 'year is required for monthly mode' if @year.blank?

      scope = scope_for_year(base_scope, @year.to_i)
      months = scope.select(Arel.sql("DISTINCT EXTRACT(MONTH FROM match_results.date_and_time)::int AS mon"))
                    .map(&:mon).compact.sort

      rows = months.map { |mon| build_row(label: "#{mon}月", scope: scope_for_month(scope, mon)) }
      rows << build_row(label: '通算', scope: scope) if rows.size > 1
      rows
    end

    # --- daily ---
    def daily_rows
      raise ArgumentError, 'year is required for daily mode' if @year.blank?

      scope = scope_for_year(base_scope, @year.to_i)
      game_results = scope.includes(game_result: { match_result: :opponent_team })
                          .order('match_results.date_and_time ASC')

      rows = game_results.map do |ba|
        mr = ba.game_result.match_result
        opponent_name = mr.opponent_team&.name || '不明'
        date_str = mr.date_and_time.strftime('%m/%d')
        build_single_row(label: "#{date_str} vs #{opponent_name}", batting_average: ba)
      end

      rows << build_row(label: '通算', scope: scope) if rows.size > 1
      rows
    end

    # --- helpers ---
    def scope_for_year(scope, yr)
      scope.where(match_results: {
                    date_and_time: Date.new(yr, 1, 1)..Date.new(yr, 12, 31)
                  })
    end

    def scope_for_month(scope, mon)
      yr = @year.to_i
      start_date = Date.new(yr, mon, 1)
      end_date = start_date.end_of_month
      scope.where(match_results: { date_and_time: start_date..end_date })
    end

    def build_row(label:, scope:)
      agg = scope.select(aggregate_columns).reorder(nil).take
      return empty_row(label) unless agg

      stats = agg.attributes
      compose_row(label, stats)
    end

    def build_single_row(label:, batting_average:)
      stats = {
        'games' => 1,
        'plate_appearances' => batting_average.plate_appearances.to_i,
        'at_bats' => batting_average.at_bats.to_i,
        'hit' => batting_average.hit.to_i,
        'two_base_hit' => batting_average.two_base_hit.to_i,
        'three_base_hit' => batting_average.three_base_hit.to_i,
        'home_run' => batting_average.home_run.to_i,
        'total_bases' => batting_average.total_bases.to_i,
        'runs_batted_in' => batting_average.runs_batted_in.to_i,
        'run' => batting_average.run.to_i,
        'strike_out' => batting_average.strike_out.to_i,
        'base_on_balls' => batting_average.base_on_balls.to_i,
        'hit_by_pitch' => batting_average.hit_by_pitch.to_i,
        'sacrifice_hit' => batting_average.sacrifice_hit.to_i,
        'sacrifice_fly' => batting_average.sacrifice_fly.to_i,
        'stealing_base' => batting_average.stealing_base.to_i,
        'caught_stealing' => batting_average.caught_stealing.to_i,
        'error' => batting_average.error.to_i
      }
      compose_row(label, stats)
    end

    def compose_row(label, s)
      games = s['games'].to_i
      at_bats = s['at_bats'].to_i
      hits = s['hit'].to_i + s['two_base_hit'].to_i + s['three_base_hit'].to_i + s['home_run'].to_i
      tb = s['hit'].to_i + (s['two_base_hit'].to_i * 2) + (s['three_base_hit'].to_i * 3) + (s['home_run'].to_i * 4)
      bb = s['base_on_balls'].to_i
      hbp = s['hit_by_pitch'].to_i
      sf = s['sacrifice_fly'].to_i
      so = s['strike_out'].to_i

      avg = safe_divide(hits.to_f, at_bats)
      slg = safe_divide(tb.to_f, at_bats)
      obp_denom = at_bats + bb + hbp + sf
      obp = safe_divide((hits + bb + hbp).to_f, obp_denom)
      ops = (obp + slg).round(3)
      iso = safe_divide((tb - hits).to_f, at_bats)
      bb_per_k = safe_divide(bb.to_f, so)

      # BABIP = (H - HR) / (AB - SO - HR + SF)
      babip_denom = at_bats - so - s['home_run'].to_i + sf
      babip = safe_divide((hits - s['home_run'].to_i).to_f, babip_denom)

      {
        label: label,
        games: games,
        plate_appearances: s['plate_appearances'].to_i,
        at_bats: at_bats,
        hit: hits,
        two_base_hit: s['two_base_hit'].to_i,
        three_base_hit: s['three_base_hit'].to_i,
        home_run: s['home_run'].to_i,
        total_bases: tb,
        runs_batted_in: s['runs_batted_in'].to_i,
        run: s['run'].to_i,
        strike_out: so,
        base_on_balls: bb,
        hit_by_pitch: hbp,
        sacrifice_hit: s['sacrifice_hit'].to_i,
        sacrifice_fly: sf,
        stealing_base: s['stealing_base'].to_i,
        caught_stealing: s['caught_stealing'].to_i,
        error: s['error'].to_i,
        batting_average: avg,
        slugging_percentage: slg,
        ops: ops,
        iso: iso,
        bb_per_k: bb_per_k,
        babip: babip
      }
    end

    def empty_row(label)
      {
        label: label, games: 0, plate_appearances: 0, at_bats: 0,
        hit: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0,
        total_bases: 0, runs_batted_in: 0, run: 0, strike_out: 0,
        base_on_balls: 0, hit_by_pitch: 0, sacrifice_hit: 0, sacrifice_fly: 0,
        stealing_base: 0, caught_stealing: 0, error: 0,
        batting_average: ZERO, slugging_percentage: ZERO, ops: ZERO,
        iso: ZERO, bb_per_k: ZERO, babip: ZERO
      }
    end

    def aggregate_columns
      [
        'COUNT(*) AS games',
        'SUM(plate_appearances) AS plate_appearances',
        'SUM(at_bats) AS at_bats',
        'SUM(hit) AS hit',
        'SUM(two_base_hit) AS two_base_hit',
        'SUM(three_base_hit) AS three_base_hit',
        'SUM(home_run) AS home_run',
        'SUM(total_bases) AS total_bases',
        'SUM(runs_batted_in) AS runs_batted_in',
        'SUM(run) AS run',
        'SUM(strike_out) AS strike_out',
        'SUM(base_on_balls) AS base_on_balls',
        'SUM(hit_by_pitch) AS hit_by_pitch',
        'SUM(sacrifice_hit) AS sacrifice_hit',
        'SUM(sacrifice_fly) AS sacrifice_fly',
        'SUM(stealing_base) AS stealing_base',
        'SUM(caught_stealing) AS caught_stealing',
        'SUM(error) AS error'
      ]
    end

    def safe_divide(numerator, denominator)
      denominator.zero? ? ZERO : (numerator / denominator).round(3)
    end
  end
end
