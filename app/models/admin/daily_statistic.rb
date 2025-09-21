module Admin
  class DailyStatistic < ApplicationRecord
    self.table_name = 'admin_daily_statistics'

    DEFAULT_RECENT_DAYS = 30
    DEFAULT_GROWTH_PERIOD_DAYS = 7
    DEFAULT_RETENTION_PERIOD_DAYS = 7
    GROWTH_COMPARISON_MULTIPLIER = 2
    PERCENTAGE_PRECISION = 2
    PERCENTAGE_BASE = 100

    validates :date, presence: true, uniqueness: true

    scope :recent, ->(days = DEFAULT_RECENT_DAYS) { where(date: days.days.ago..Date.current).order(:date) }
    scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date).order(:date) }

    class << self
      def calculate_for_date(date = Date.current)
        stats = find_or_initialize_by(date:)

        stats.total_users = User.where('created_at <= ?', date.end_of_day).count
        stats.new_users = User.where(created_at: date.all_day).count
        stats.active_users = calculate_active_users(date)
        stats.total_games = GameResult.where(created_at: date.all_day).count
        stats.total_batting_records = BattingAverage.where(created_at: date.all_day).count
        stats.total_pitching_records = PitchingResult.where(created_at: date.all_day).count
        stats.total_posts = [
          BattingAverage.where(created_at: date.all_day).count,
          PitchingResult.where(created_at: date.all_day).count,
          BaseballNote.where(created_at: date.all_day).count
        ].sum

        stats.save!
        stats
      end

      def calculate_batch(start_date, end_date)
        (start_date..end_date).each do |date|
          calculate_for_date(date)
        end
      end

      def growth_rate(metric, days = DEFAULT_GROWTH_PERIOD_DAYS)
        comparison_period = days * GROWTH_COMPARISON_MULTIPLIER
        recent_stats = recent(comparison_period).pluck(:date, metric)
        return 0 if recent_stats.length < comparison_period

        current_period = recent_stats.last(days).sum { |stat| stat[1] }
        previous_period = recent_stats.first(days).sum { |stat| stat[1] }

        return 0 if previous_period.zero?

        ((current_period.to_f - previous_period) / previous_period * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      def retention_rate(cohort_date, period_days = DEFAULT_RETENTION_PERIOD_DAYS)
        cohort_users = User.where(created_at: cohort_date.all_day)
        return 0 if cohort_users.count.zero?

        retention_date = cohort_date + period_days.days
        retained_user_ids = calculate_active_user_ids(retention_date)
        cohort_user_ids = cohort_users.pluck(:id)

        retained_count = (retained_user_ids & cohort_user_ids).count
        (retained_count.to_f / cohort_users.count * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
      end

      private

      def calculate_active_users(date)
        calculate_active_user_ids(date).count
      end

      def calculate_active_user_ids(date)
        login_user_ids = User.where(last_login_at: date.all_day).pluck(:id)

        content_user_ids = []
        content_user_ids += GameResult.where(created_at: date.all_day).pluck(:user_id)
        content_user_ids += BattingAverage.where(created_at: date.all_day).pluck(:user_id)
        content_user_ids += PitchingResult.where(created_at: date.all_day).pluck(:user_id)
        content_user_ids += BaseballNote.where(created_at: date.all_day).pluck(:user_id) if defined?(BaseballNote)

        (login_user_ids + content_user_ids).uniq
      end
    end

    def growth_comparison(metric)
      previous_day = Admin::DailyStatistic.find_by(date: date - 1.day)
      return 0 unless previous_day

      current_value = send(metric)
      previous_value = previous_day.send(metric)

      return 0 if previous_value.zero?

      ((current_value.to_f - previous_value) / previous_value * PERCENTAGE_BASE).round(PERCENTAGE_PRECISION)
    end
  end
end
