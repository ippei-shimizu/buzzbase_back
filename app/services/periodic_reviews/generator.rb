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

    def previous_range
      length = (period_end - @period_start).to_i + 1
      (@period_start - length)..(@period_start - 1)
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
        'streak_current' => Activities::StreakCalculator.new(@user).current
      }
    end

    def advanced_summary
      {
        'theme_breakdown' => theme_breakdown,
        'condition' => condition_summary,
        'batting' => batting_summary,
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
      current = batting_average_for(range)
      previous = batting_average_for(previous_range)
      {
        'batting_average' => current,
        'previous_batting_average' => previous,
        'delta' => (current - previous).round(3)
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
