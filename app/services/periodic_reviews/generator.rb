module PeriodicReviews
  # 週次 / 月次の振り返りレポートを生成（upsert）する。
  # 練習量・Streak（全員に見せる基本部）に加え、課題別内訳・コンディション・成績前週比・
  # 相関インサイト（Pro 限定の詳細部）を summary にまとめて保存する。出し分けはシリアライザ側。
  class Generator
    JST = 'Asia/Tokyo'.freeze

    # @param user [User]
    # @param period_type [String] 'weekly' / 'monthly'
    # @param period_start [Date] 期間の開始日（週=月曜 / 月=1日）
    def initialize(user:, period_type:, period_start:)
      @user = user
      @period_type = period_type
      @period_start = period_start
    end

    # @return [PeriodicReview] 保存済みレポート
    def call
      review = @user.periodic_reviews.find_or_initialize_by(period_type: @period_type, period_start: @period_start)
      review.update!(period_end:, summary: build_summary)
      review
    end

    private

    def period_end
      @period_end ||= @period_type == 'monthly' ? @period_start.end_of_month : @period_start + 6
    end

    # 月次は月ごとに日数が異なるため、固定日数ではなく前月の暦月で比較する。
    def previous_range
      if @period_type == 'monthly'
        previous_month_start = (@period_start - 1.month).beginning_of_month
        previous_month_start..previous_month_start.end_of_month
      else
        length = (period_end - @period_start).to_i + 1
        (@period_start - length)..(@period_start - 1)
      end
    end

    def build_summary
      basic_summary.merge(advanced_summary)
    end

    def basic_summary
      logs = activity_logs_in(range)
      {
        'period_type' => @period_type,
        'practice_days' => logs.count { |log| log.intensity_level >= 1 },
        'total_swings' => logs.sum(&:total_swing_count),
        'active_days' => logs.size,
        'streak_current' => Activities::StreakCalculator.new(@user).current,
        'batting' => batting_summary,
        'pitching' => pitching_summary
      }
    end

    def advanced_summary
      {
        'theme_breakdown' => theme_breakdown,
        'condition' => condition_summary,
        'insight' => representative_insight
      }
    end

    def range
      @range ||= @period_start..period_end
    end

    def activity_logs_in(date_range)
      @user.activity_logs.where(activity_date: date_range).to_a
    end

    # 取組中の課題ごとの、この期間の練習セッション数。
    def theme_breakdown
      @user.improvement_themes.where(status: 'open').map do |theme|
        {
          'id' => theme.id,
          'title' => theme.title,
          'practice_count' => theme.practice_sessions.where(logged_on: range).count
        }
      end
    end

    def condition_summary
      logs = @user.condition_logs.where(logged_on: range).to_a
      sleeps = logs.filter_map(&:sleep_hours)
      levels = logs.filter_map(&:fatigue_level)
      {
        'sleep_hours_avg' => average(sleeps),
        'fatigue_level_avg' => average(levels)
      }
    end

    def batting_summary
      agg = batting_aggregates(range)
      obp = Stats::BattingFormulas.on_base_percentage(
        total_hits: agg[:total_hits], base_on_balls: agg[:bb], hit_by_pitch: agg[:hbp],
        at_bats: agg[:at_bats], sacrifice_fly: agg[:sf]
      )
      slg = Stats::BattingFormulas.slugging_percentage(total_bases: agg[:total_bases], at_bats: agg[:at_bats])
      current = Stats::BattingFormulas.batting_average(total_hits: agg[:total_hits], at_bats: agg[:at_bats])
      previous = batting_average_for(previous_range)
      {
        'batting_average' => current,
        'on_base_percentage' => obp,
        'slugging_percentage' => slg,
        'ops' => Stats::BattingFormulas.ops(obp:, slg:),
        'previous_batting_average' => previous,
        'delta' => (current - previous).round(3)
      }
    end

    # 投手成績（防御率 / WHIP / K/9）。登板が無ければ各値 nil。
    def pitching_summary
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      row = @user.game_results.joins(:match_result, :pitching_result)
                 .where("DATE(#{date_sql}) BETWEEN ? AND ?", range.first, range.last)
                 .pick(
                   Arel.sql('SUM(COALESCE(pitching_results.innings_pitched, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.earned_run, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.hits_allowed, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.base_on_balls, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.strikeouts, 0))')
                 )
      innings, earned, hits, walks, strikeouts = row.map(&:to_f)
      {
        'innings_pitched' => innings.round(1),
        'era' => innings.zero? ? nil : (earned * 9 / innings).round(2),
        'whip' => innings.zero? ? nil : ((walks + hits) / innings).round(2),
        'k_per_9' => innings.zero? ? nil : (strikeouts * 9 / innings).round(1)
      }
    end

    def batting_aggregates(date_range)
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      row = @user.game_results.joins(:match_result, :batting_average)
                 .where("DATE(#{date_sql}) BETWEEN ? AND ?", date_range.first, date_range.last)
                 .pick(
                   Arel.sql("SUM(#{Stats::BattingFormulas::TOTAL_HITS_SQL})"),
                   Arel.sql('SUM(COALESCE(batting_averages.at_bats, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.total_bases, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.base_on_balls, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.hit_by_pitch, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.sacrifice_fly, 0))')
                 )
      {
        total_hits: row[0].to_i, at_bats: row[1].to_i, total_bases: row[2].to_i,
        bb: row[3].to_i, hbp: row[4].to_i, sf: row[5].to_i
      }
    end

    # 期間中で最も傾向が強い（strong かつ十分なサンプル）インサイトを1つ選ぶ。
    def representative_insight
      cards = Insights::CorrelationBuilder.new(user: @user).call
      cards.select { |card| card[:sufficient] }.max_by { |card| card[:strength] == 'strong' ? 1 : 0 }
    end

    # 指定 JST 日付レンジの打率（総安打 / 打数）。
    def batting_average_for(date_range)
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      rows = @user.game_results.joins(:match_result, :batting_average)
                  .where("DATE(#{date_sql}) BETWEEN ? AND ?", date_range.first, date_range.last)
                  .pluck(Arel.sql("SUM(#{Stats::BattingFormulas::TOTAL_HITS_SQL})"),
                         Arel.sql('SUM(COALESCE(batting_averages.at_bats, 0))'))
      total_hits, at_bats = rows.first
      Stats::BattingFormulas.batting_average(total_hits: total_hits.to_i, at_bats: at_bats.to_i)
    end

    def average(values)
      return nil if values.empty?

      (values.sum.to_f / values.size).round(1)
    end
  end
end
