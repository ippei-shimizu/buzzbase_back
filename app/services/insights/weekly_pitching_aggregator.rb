module Insights
  # 週（JST 月〜日）ごとの投手指標（防御率・WHIP・与四球率/9）を集計する。
  # 相関の「成績側」変数（投手）として使う。ERA 等は試合ごとの inning_format（7 or 9）で
  # earned_run / base_on_balls を加重してから投球回で割る（Stats::EraTrendService と同じ方式）。
  class WeeklyPitchingAggregator
    # @param user [User]
    # @param since [Date] この日付以降（JST）の登板を対象にする
    def initialize(user:, since:)
      @user = user
      @since = since
    end

    # @return [Hash{Date=>Hash}] 週開始日 => { era:, whip:, bb_per9: }（登板が無い週は含めない）
    def call
      grouped = pitching_rows.group_by { |row| row[:date].beginning_of_week }
      grouped.each_with_object({}) do |(week_start, rows), result|
        metrics = week_metrics(rows)
        result[week_start] = metrics if metrics
      end
    end

    private

    def week_metrics(rows)
      innings = rows.sum { |row| row[:innings_pitched] }
      return nil if innings.zero?

      weighted_earned = rows.sum { |row| row[:earned_run] * row[:inning_format] }
      weighted_walks = rows.sum { |row| row[:base_on_balls] * row[:inning_format] }
      hits = rows.sum { |row| row[:hits_allowed] }
      walks = rows.sum { |row| row[:base_on_balls] }
      {
        era: (weighted_earned / innings).round(2),
        whip: ((walks + hits) / innings).round(2),
        bb_per9: (weighted_walks / innings).round(2)
      }
    end

    def pitching_rows
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      @user.game_results.joins(:match_result, :pitching_result)
           .where("#{date_sql} >= ?", @since.beginning_of_day)
           .pluck(Arel.sql(<<~SQL.squish))
             DATE(#{date_sql}),
             COALESCE(pitching_results.innings_pitched, 0),
             COALESCE(pitching_results.earned_run, 0),
             COALESCE(pitching_results.hits_allowed, 0),
             COALESCE(pitching_results.base_on_balls, 0),
             match_results.inning_format
           SQL
           .map do |row|
        { date: row[0], innings_pitched: row[1].to_f, earned_run: row[2].to_f,
          hits_allowed: row[3].to_f, base_on_balls: row[4].to_f, inning_format: row[5].to_f }
      end
    end
  end
end
