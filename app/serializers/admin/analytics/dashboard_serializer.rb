module Admin
  module Analytics
    class DashboardSerializer
      class << self
        def serialize(stats_data, granularity = 'daily')
          latest_stat = stats_data.last
          previous_stat = stats_data[-2] if stats_data.length > 1

          {
            total_users: latest_stat&.total_users || 0,
            daily_active_users: latest_stat&.active_users || 0,
            new_registrations: latest_stat&.new_users || 0,
            monthly_active_users: calculate_mau(stats_data),
            user_growth_data: ::Admin::Analytics::UserGrowthSerializer.serialize(stats_data, granularity),
            activity_data: ::Admin::Analytics::ActivityTrendsSerializer.serialize(stats_data, granularity),
            growth_rates: build_growth_rates(latest_stat, previous_stat),
            granularity: granularity,
            period_count: stats_data.length
          }
        end

        private

        def calculate_mau(daily_stats)
          return 0 if daily_stats.empty?

          latest_date = daily_stats.last&.date || Date.current
          start_date = latest_date - 29.days

          calculate_actual_mau(start_date, latest_date)
        end

        def calculate_actual_mau(start_date, end_date)
          login_user_ids = ::User.where(last_login_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:id)

          content_user_ids = []
          content_user_ids += ::GameResult.where(created_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:user_id)
          content_user_ids += ::BattingAverage.where(created_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:user_id)
          content_user_ids += ::PitchingResult.where(created_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:user_id)

          if defined?(::BaseballNote)
            content_user_ids += ::BaseballNote.where(created_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:user_id)
          end

          (login_user_ids + content_user_ids).uniq.count
        end

        def build_growth_rates(latest_stat, previous_stat)
          return {} unless latest_stat && previous_stat

          {
            users: calculate_growth_rate(latest_stat.total_users, previous_stat.total_users),
            dau: calculate_growth_rate(latest_stat.active_users, previous_stat.active_users),
            new_users: calculate_growth_rate(latest_stat.new_users, previous_stat.new_users)
          }
        end

        def calculate_growth_rate(current, previous)
          return 0 if previous.nil? || previous.zero?

          ((current.to_f - previous) / previous * 100).round(2)
        end
      end
    end
  end
end
