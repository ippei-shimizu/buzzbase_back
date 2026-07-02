module Insights
  # 週（JST 月〜日）ごとの打撃指標（打率・OPS・三振率）を集計する。
  # 相関インサイトの「成績側」変数として使う。指標算出は Stats::BattingFormulas に委譲する。
  class WeeklyBattingAggregator
    SUM_KEYS = %i[singles doubles triples home_runs at_bats walks hbp sac_fly strike_outs plate_appearances].freeze

    # @param user [User]
    # @param since [Date] この日付以降（JST）の試合を対象にする
    def initialize(user:, since:)
      @user = user
      @since = since
    end

    # @return [Hash{Date=>Hash}] 週開始日 => { batting_average:, ops:, strikeout_rate: }
    def call
      batting_rows.group_by { |row| row[:date].beginning_of_week }
                  .transform_values { |week_rows| week_metrics(week_rows) }
    end

    private

    def week_metrics(rows)
      totals = sum_batting(rows)
      total_hits = totals[:singles] + totals[:doubles] + totals[:triples] + totals[:home_runs]
      total_bases = Stats::BattingFormulas.total_bases(singles: totals[:singles], doubles: totals[:doubles],
                                                       triples: totals[:triples], home_runs: totals[:home_runs])
      obp = Stats::BattingFormulas.on_base_percentage(total_hits:, base_on_balls: totals[:walks],
                                                      hit_by_pitch: totals[:hbp], at_bats: totals[:at_bats],
                                                      sacrifice_fly: totals[:sac_fly])
      slg = Stats::BattingFormulas.slugging_percentage(total_bases:, at_bats: totals[:at_bats])
      {
        batting_average: Stats::BattingFormulas.batting_average(total_hits:, at_bats: totals[:at_bats]),
        ops: Stats::BattingFormulas.ops(obp:, slg:),
        strikeout_rate: Stats::BattingFormulas.safe_divide(totals[:strike_outs], totals[:plate_appearances])
      }
    end

    def sum_batting(rows)
      SUM_KEYS.index_with { |key| rows.sum { |row| row[key] } }
    end

    def batting_rows
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      @user.game_results.joins(:match_result, :batting_average)
           .where("#{date_sql} >= ?", @since.beginning_of_day)
           .pluck(Arel.sql(<<~SQL.squish))
             DATE(#{date_sql}),
             COALESCE(batting_averages.hit, 0), COALESCE(batting_averages.two_base_hit, 0),
             COALESCE(batting_averages.three_base_hit, 0), COALESCE(batting_averages.home_run, 0),
             COALESCE(batting_averages.at_bats, 0), COALESCE(batting_averages.base_on_balls, 0),
             COALESCE(batting_averages.hit_by_pitch, 0), COALESCE(batting_averages.sacrifice_fly, 0),
             COALESCE(batting_averages.strike_out, 0), COALESCE(batting_averages.plate_appearances, 0)
           SQL
           .map do |row|
        { date: row[0], singles: row[1], doubles: row[2], triples: row[3], home_runs: row[4],
          at_bats: row[5], walks: row[6], hbp: row[7], sac_fly: row[8],
          strike_outs: row[9], plate_appearances: row[10] }
      end
    end
  end
end
