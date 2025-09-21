module Admin
  class MonthlyStatistic < ApplicationRecord
    self.table_name = 'admin_monthly_statistics'

    DEFAULT_RECENT_MONTHS = 12
    MIN_VALID_YEAR = 1900
    MIN_MONTH = 1
    MAX_MONTH = 12
    PERCENTAGE_BASE = 100
    PERCENTAGE_PRECISION = 2
    ENGAGEMENT_ACTIVE_USER_WEIGHT = 0.5
    ENGAGEMENT_CONTENT_CREATOR_WEIGHT = 0.5
    MAX_ENGAGEMENT_SCORE = 100.0

    validates :year, presence: true, numericality: { greater_than: MIN_VALID_YEAR }
    validates :month, presence: true, numericality: { in: MIN_MONTH..MAX_MONTH }
    validates :month_start_date, presence: true
    validates :month_end_date, presence: true
    validates :total_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :avg_daily_active_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :peak_daily_active_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :avg_weekly_active_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :new_users, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_games, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_posts, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_batting_records, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :total_pitching_records, presence: true, numericality: { greater_than_or_equal_to: 0 }

    validates :year, uniqueness: { scope: :month }

    scope :by_date_range, lambda { |start_date, end_date|
      where(month_start_date: start_date..end_date)
    }
    scope :recent, ->(limit = DEFAULT_RECENT_MONTHS) { order(year: :desc, month: :desc).limit(limit) }

    class << self
      # rubocop:disable Metrics/MethodLength
      def calculate_for_month(date)
        month_start = date.beginning_of_month
        month_end = date.end_of_month

        existing_stat = find_by(year: date.year, month: date.month)
        return existing_stat if existing_stat

        daily_stats = Admin::DailyStatistic.by_date_range(month_start, month_end)
        return nil if daily_stats.empty?

        latest_daily_stat = daily_stats.order(:date).last
        avg_daily_active = daily_stats.average(:active_users).to_f
        peak_daily_active = daily_stats.maximum(:active_users)

        weekly_stats = Admin::WeeklyStatistic.by_date_range(month_start.beginning_of_week(:monday), month_end.end_of_week(:monday))
        avg_weekly_active = weekly_stats.any? ? weekly_stats.average(:avg_daily_active_users).to_f : avg_daily_active

        retention_rate = calculate_monthly_retention_rate(month_start)
        growth_rate = calculate_monthly_growth_rate(date.year, date.month)
        engagement_score = calculate_engagement_score(daily_stats, latest_daily_stat)

        create!(
          year: date.year,
          month: date.month,
          month_start_date: month_start,
          month_end_date: month_end,
          total_users: latest_daily_stat.total_users,
          avg_daily_active_users: avg_daily_active.round(2),
          peak_daily_active_users: peak_daily_active,
          avg_weekly_active_users: avg_weekly_active.round(2),
          new_users: daily_stats.sum(:new_users),
          total_games: daily_stats.sum(:total_games),
          total_posts: daily_stats.sum(:total_posts),
          total_batting_records: daily_stats.sum(:total_batting_records),
          total_pitching_records: daily_stats.sum(:total_pitching_records),
          monthly_retention_rate: retention_rate,
          user_growth_rate: growth_rate,
          engagement_score:
        )
      end
      # rubocop:enable Metrics/MethodLength

      def calculate_batch(start_date, end_date)
        current_date = start_date.beginning_of_month

        while current_date <= end_date
          calculate_for_month(current_date)
          current_date += 1.month
        end
      end

      def growth_rate(metric, months_ago = 1)
        current_month = recent(1).first
        previous_month = recent(months_ago + 1).offset(months_ago).first

        return 0.0 unless current_month && previous_month

        current_value = current_month.send(metric)
        previous_value = previous_month.send(metric)

        return 0.0 if previous_value.zero?

        ((current_value - previous_value) / previous_value.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      def retention_rate(cohort_date, period_days)
        cohort_start = cohort_date.beginning_of_month
        cohort_end = cohort_date.end_of_month

        check_start = cohort_end + 1.day
        check_end = check_start + period_days.days - 1.day

        new_users_in_cohort = User.where(created_at: cohort_start.beginning_of_day..cohort_end.end_of_day)
        return 0.0 if new_users_in_cohort.count.zero?

        active_in_period = new_users_in_cohort.joins(:game_results, :batting_averages, :pitching_results)
                                              .where(
                                                'game_results.created_at BETWEEN ? AND ? OR batting_averages.created_at BETWEEN ? AND ? OR pitching_results.created_at BETWEEN ? AND ? OR users.last_login_at BETWEEN ? AND ?',
                                                check_start.beginning_of_day, check_end.end_of_day,
                                                check_start.beginning_of_day, check_end.end_of_day,
                                                check_start.beginning_of_day, check_end.end_of_day,
                                                check_start.beginning_of_day, check_end.end_of_day
                                              ).distinct.count

        (active_in_period / new_users_in_cohort.count.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      private

      def calculate_monthly_retention_rate(month_start)
        cohort_start = month_start - 1.month
        cohort_end = cohort_start.end_of_month

        new_users_previous_month = User.where(created_at: cohort_start.beginning_of_day..cohort_end.end_of_day)
        return 0.0 if new_users_previous_month.count.zero?

        active_in_current_month = new_users_previous_month.joins(:game_results, :batting_averages, :pitching_results)
                                                          .where(
                                                            'game_results.created_at BETWEEN ? AND ? OR batting_averages.created_at BETWEEN ? AND ? OR pitching_results.created_at BETWEEN ? AND ? OR users.last_login_at BETWEEN ? AND ?',
                                                            month_start.beginning_of_day, month_start.end_of_month.end_of_day,
                                                            month_start.beginning_of_day, month_start.end_of_month.end_of_day,
                                                            month_start.beginning_of_day, month_start.end_of_month.end_of_day,
                                                            month_start.beginning_of_day, month_start.end_of_month.end_of_day
                                                          ).distinct.count

        (active_in_current_month / new_users_previous_month.count.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      def calculate_monthly_growth_rate(year, month)
        current_month_stats = find_by(year:, month:)

        previous_year = month == MIN_MONTH ? year - 1 : year
        previous_month = month == MIN_MONTH ? MAX_MONTH : month - 1
        previous_month_stats = find_by(year: previous_year, month: previous_month)

        return 0.0 unless current_month_stats && previous_month_stats
        return 0.0 if previous_month_stats.total_users.zero?

        growth = current_month_stats.total_users - previous_month_stats.total_users
        (growth / previous_month_stats.total_users.to_f * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      def calculate_engagement_score(daily_stats, latest_daily_stat)
        return 0.0 if latest_daily_stat.total_users.zero?

        avg_active_users = daily_stats.average(:active_users).to_f
        active_user_rate = (avg_active_users / latest_daily_stat.total_users) * PERCENTAGE_BASE

        total_content_created = daily_stats.sum(:total_games) +
                                daily_stats.sum(:total_batting_records) +
                                daily_stats.sum(:total_pitching_records)

        content_creator_rate = if avg_active_users.positive?
                                 (total_content_created / (avg_active_users * daily_stats.count)) * PERCENTAGE_BASE
                               else
                                 0.0
                               end

        engagement_score = (active_user_rate * ENGAGEMENT_ACTIVE_USER_WEIGHT) + (content_creator_rate * ENGAGEMENT_CONTENT_CREATOR_WEIGHT)
        [engagement_score, MAX_ENGAGEMENT_SCORE].min.round(PERCENTAGE_PRECISION)
      end
    end
  end
end
