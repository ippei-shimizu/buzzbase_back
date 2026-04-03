# frozen_string_literal: true

module Stats
  class PitchingStatsTableService
    ZERO = 0
    INNINGS_PER_GAME = 9

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
      PitchingResult.joins(game_result: :match_result)
                    .where(pitching_results: { user_id: @user_id })
                    .where('pitching_results.innings_pitched > 0')
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
      records = scope.includes(game_result: { match_result: :opponent_team })
                     .order('match_results.date_and_time ASC')

      rows = records.map do |pr|
        mr = pr.game_result.match_result
        opponent_name = mr.opponent_team&.name || '不明'
        date_str = mr.date_and_time.strftime('%m/%d')
        build_single_row(label: "#{date_str} vs #{opponent_name}", pitching_result: pr)
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

      compose_row(label, agg.attributes)
    end

    def build_single_row(label:, pitching_result:)
      pr = pitching_result
      stats = {
        'appearances' => 1,
        'win' => pr.win.to_i,
        'loss' => pr.loss.to_i,
        'hold' => pr.hold.to_i,
        'saves' => pr.saves.to_i,
        'complete_games' => pr.got_to_the_distance ? 1 : 0,
        'shutouts' => (pr.got_to_the_distance && pr.run_allowed.to_i.zero?) ? 1 : 0,
        'innings_pitched' => pr.innings_pitched.to_f,
        'hits_allowed' => pr.hits_allowed.to_i,
        'home_runs_hit' => pr.home_runs_hit.to_i,
        'strikeouts' => pr.strikeouts.to_i,
        'base_on_balls' => pr.base_on_balls.to_i,
        'hit_by_pitch' => pr.hit_by_pitch.to_i,
        'earned_run' => pr.earned_run.to_i
      }
      compose_row(label, stats)
    end

    def compose_row(label, s)
      ip = s['innings_pitched'].to_f
      wins = s['win'].to_i
      losses = s['loss'].to_i
      so = s['strikeouts'].to_i
      bb = s['base_on_balls'].to_i

      {
        label: label,
        appearances: s['appearances'].to_i,
        win: wins,
        loss: losses,
        hold: s['hold'].to_i,
        saves: s['saves'].to_i,
        complete_games: s['complete_games'].to_i,
        shutouts: s['shutouts'].to_i,
        innings_pitched: ip.round(1),
        hits_allowed: s['hits_allowed'].to_i,
        home_runs_hit: s['home_runs_hit'].to_i,
        strikeouts: so,
        base_on_balls: bb,
        hit_by_pitch: s['hit_by_pitch'].to_i,
        earned_run: s['earned_run'].to_i,
        era: safe_divide(s['earned_run'].to_f * INNINGS_PER_GAME, ip, 2),
        whip: safe_divide(bb.to_f + s['hits_allowed'].to_f, ip, 3),
        k_per_nine: safe_divide(so.to_f * 9, ip, 3),
        bb_per_nine: safe_divide(bb.to_f * 9, ip, 3),
        k_bb: safe_divide(so.to_f, bb, 3),
        win_percentage: safe_divide(wins.to_f, wins + losses, 3)
      }
    end

    def empty_row(label)
      {
        label: label, appearances: 0, win: 0, loss: 0, hold: 0, saves: 0,
        complete_games: 0, shutouts: 0, innings_pitched: 0.0,
        hits_allowed: 0, home_runs_hit: 0, strikeouts: 0,
        base_on_balls: 0, hit_by_pitch: 0, earned_run: 0,
        era: ZERO, whip: ZERO, k_per_nine: ZERO, bb_per_nine: ZERO,
        k_bb: ZERO, win_percentage: ZERO
      }
    end

    def aggregate_columns
      [
        'COUNT(*) AS appearances',
        'SUM(win) AS win',
        'SUM(loss) AS loss',
        'SUM(hold) AS hold',
        'SUM(saves) AS saves',
        'SUM(CASE WHEN got_to_the_distance THEN 1 ELSE 0 END) AS complete_games',
        "SUM(CASE WHEN got_to_the_distance = true AND run_allowed = 0 THEN 1 ELSE 0 END) AS shutouts",
        'ROUND(SUM(innings_pitched)::numeric, 1) AS innings_pitched',
        'SUM(hits_allowed) AS hits_allowed',
        'SUM(home_runs_hit) AS home_runs_hit',
        'SUM(strikeouts) AS strikeouts',
        'SUM(base_on_balls) AS base_on_balls',
        'SUM(hit_by_pitch) AS hit_by_pitch',
        'SUM(earned_run) AS earned_run'
      ]
    end

    def safe_divide(numerator, denominator, precision)
      denominator.zero? ? ZERO : (numerator / denominator).round(precision)
    end
  end
end
