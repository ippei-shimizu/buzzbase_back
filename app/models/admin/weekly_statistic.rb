module Admin
  class WeeklyStatistic < ApplicationRecord
    self.table_name = 'admin_weekly_statistics'

    DEFAULT_RECENT_WEEKS = 12
    DEFAULT_COMPARISON_WEEKS = 1
    PERCENTAGE_BASE = 100
    PERCENTAGE_PRECISION = 2

    validates :week_start_date, presence: true, uniqueness: true
    validates :week_end_date, presence: true
    validates :total_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :avg_daily_active_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :peak_daily_active_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :new_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_games, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_posts, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_batting_records, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_pitching_records, presence: true, numericality: { greater_than_or_equal_to: 0 }

    scope :by_date_range, lambda { |start_date, end_date|
      where(week_start_date: start_date..end_date)
    }
    scope :recent, ->(limit = DEFAULT_RECENT_WEEKS) { order(week_start_date: :desc).limit(limit) }

    class << self
      def calculate_for_week(date)
        week_start = date.beginning_of_week(:monday)
        week_end = date.end_of_week(:monday)

        existing_stat = find_by(week_start_date: week_start)
        return existing_stat if existing_stat

        daily_stats = Admin::DailyStatistic.by_date_range(week_start, week_end)
        return nil if daily_stats.empty?

        latest_daily_stat = daily_stats.order(:date).last
        avg_active_users = daily_stats.average(:active_users).to_f
        peak_active_users = daily_stats.maximum(:active_users)

        retention_rate = calculate_weekly_retention_rate(week_start)
        growth_rate = calculate_weekly_growth_rate(week_start)

        create!(
          week_start_date: week_start,
          week_end_date: week_end,
          total_users: latest_daily_stat.total_users,
          avg_daily_active_users: avg_active_users.round(2),
          peak_daily_active_users: peak_active_users,
          new_users: daily_stats.sum(:new_users),
          total_games: daily_stats.sum(:total_games),
          total_posts: daily_stats.sum(:total_posts),
          total_batting_records: daily_stats.sum(:total_batting_records),
          total_pitching_records: daily_stats.sum(:total_pitching_records),
          weekly_retention_rate: retention_rate,
          user_growth_rate: growth_rate
        )
      end

      def calculate_batch(start_date, end_date)
        current_date = start_date.beginning_of_week(:monday)

        while current_date <= end_date
          calculate_for_week(current_date)
          current_date += 1.week
        end
      end

      def growth_rate(metric, weeks_ago = DEFAULT_COMPARISON_WEEKS)
        current_week = recent(1).first
        previous_week = recent(weeks_ago + 1).offset(weeks_ago).first

        return 0.0 unless current_week && previous_week

        current_value = current_week.send(metric)
        previous_value = previous_week.send(metric)

        return 0.0 if previous_value.zero?

        ((current_value - previous_value) / previous_value.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      private

      def calculate_weekly_retention_rate(week_start)
        cohort_start = week_start - 1.week
        cohort_end = cohort_start.end_of_week(:monday)

        new_users_previous_week = ::User.where(created_at: cohort_start.beginning_of_day..cohort_end.end_of_day)
        return 0.0 if new_users_previous_week.count.zero?

        active_in_current_week = new_users_previous_week.joins(:game_results, :batting_averages, :pitching_results)
                                                        .where(
                                                          'game_results.created_at BETWEEN ? AND ? OR batting_averages.created_at BETWEEN ? AND ? OR pitching_results.created_at BETWEEN ? AND ? OR users.last_login_at BETWEEN ? AND ?',
                                                          week_start.beginning_of_day, week_start.end_of_week(:monday).end_of_day,
                                                          week_start.beginning_of_day, week_start.end_of_week(:monday).end_of_day,
                                                          week_start.beginning_of_day, week_start.end_of_week(:monday).end_of_day,
                                                          week_start.beginning_of_day, week_start.end_of_week(:monday).end_of_day
                                                        ).distinct.count

        (active_in_current_week / new_users_previous_week.count.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      def calculate_weekly_growth_rate(week_start)
        current_week_stats = find_by(week_start_date: week_start)
        previous_week_stats = find_by(week_start_date: week_start - 1.week)

        return 0.0 unless current_week_stats && previous_week_stats
        return 0.0 if previous_week_stats.total_users.zero?

        growth = current_week_stats.total_users - previous_week_stats.total_users
        (growth / previous_week_stats.total_users.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end
    end
  end
end
