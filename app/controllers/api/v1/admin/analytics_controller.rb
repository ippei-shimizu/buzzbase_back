module Api
  module V1
    module Admin
      class AnalyticsController < Api::V1::Admin::BaseController
        def dashboard
          period = analytics_params[:period]&.to_i || 30
          granularity = analytics_params[:granularity] || 'daily'

          stats_data = case granularity
                       when 'weekly'
                         get_weekly_stats(period)
                       when 'monthly'
                         get_monthly_stats(period)
                       else
                         ::Admin::DailyStatistic.recent(period)
                       end

          dashboard_data = if stats_data.empty?
                             build_realtime_dashboard_data
                           else
                             ::Admin::Analytics::DashboardSerializer.serialize(stats_data, granularity)
                           end

          render json: dashboard_data
        end

        private

        def build_realtime_dashboard_data
          current_date = Date.current

          {
            total_users: ::User.count,
            daily_active_users: calculate_realtime_dau(current_date),
            new_registrations: ::User.where(created_at: current_date.all_day).count,
            monthly_active_users: calculate_realtime_mau(current_date),
            user_growth_data: ::Admin::Analytics::UserGrowthSerializer.serialize(build_realtime_daily_stats),
            activity_data: ::Admin::Analytics::ActivityTrendsSerializer.serialize(build_realtime_daily_stats),
            growth_rates: {}
          }
        end

        def calculate_realtime_dau(date)
          ::Admin::DailyStatistic.send(:calculate_active_users, date)
        end

        def calculate_realtime_mau(date)
          start_date = date - 29.days
          ::Admin::Analytics::DashboardSerializer.send(:calculate_actual_mau, start_date, date)
        end

        def build_realtime_daily_stats
          (6.days.ago.to_date..Date.current).map do |date|
            build_daily_stat_hash(date)
          end
        end

        def build_daily_stat_hash(date)
          {
            date:,
            new_users: ::User.where(created_at: date.all_day).count,
            total_users: ::User.where('created_at <= ?', date.end_of_day).count,
            active_users: ::Admin::DailyStatistic.send(:calculate_active_users, date),
            total_games: ::GameResult.where(created_at: date.all_day).count,
            total_batting_records: ::BattingAverage.where(created_at: date.all_day).count,
            total_pitching_records: ::PitchingResult.where(created_at: date.all_day).count,
            total_posts: calculate_total_posts(date)
          }
        end

        def calculate_total_posts(date)
          [
            ::BattingAverage.where(created_at: date.all_day).count,
            ::PitchingResult.where(created_at: date.all_day).count,
            ::BaseballNote.where(created_at: date.all_day).count
          ].sum
        end

        def trends
          start_date = analytics_params[:start_date]&.to_date || 30.days.ago.to_date
          end_date = analytics_params[:end_date]&.to_date || Date.current

          trends_data = Admin::Analytics::TrendsService.new(start_date, end_date).call
          render json: { trends: trends_data }
        end

        def features
          start_date = analytics_params[:start_date]&.to_date || 30.days.ago.to_date
          end_date = analytics_params[:end_date]&.to_date || Date.current

          features_data = Admin::Analytics::FeaturesService.new(start_date, end_date).call
          render json: { features: features_data }
        end

        def users
          users_data = Admin::Analytics::UsersService.new(params).call
          render json: users_data
        end

        def retention
          cohort_date = analytics_params[:cohort_date]&.to_date || 7.days.ago.to_date
          period = analytics_params[:period]&.to_i || 7

          retention_data = Admin::Analytics::RetentionService.new(cohort_date, period).call
          render json: { retention: retention_data }
        end

        def get_weekly_stats(weeks_count)
          start_date = weeks_count.weeks.ago.beginning_of_week
          end_date = Date.current.end_of_week

          daily_stats = ::Admin::DailyStatistic.where(date: start_date..end_date)

          daily_stats.group_by { |stat| stat.date.beginning_of_week }
                     .map do |week_start, stats|
            aggregate_stats_for_period(stats, week_start, 'week')
          end.sort_by(&:date)
        end

        def get_monthly_stats(months_count)
          start_date = months_count.months.ago.beginning_of_month
          end_date = Date.current.end_of_month

          daily_stats = ::Admin::DailyStatistic.where(date: start_date..end_date)

          daily_stats.group_by { |stat| stat.date.beginning_of_month }
                     .map do |month_start, stats|
            aggregate_stats_for_period(stats, month_start, 'month')
          end.sort_by(&:date)
        end

        def aggregate_stats_for_period(stats, period_start, period_type)
          last_stat = find_latest_stat(stats)

          {
            date: period_start,
            total_users: last_stat&.fetch(:total_users, 0) || 0,
            active_users: sum_stat_values(stats, :active_users),
            new_users: sum_stat_values(stats, :new_users),
            total_games: sum_stat_values(stats, :total_games),
            total_batting_records: sum_stat_values(stats, :total_batting_records),
            total_pitching_records: sum_stat_values(stats, :total_pitching_records),
            total_posts: sum_stat_values(stats, :total_posts),
            period_type:
          }
        end

        def find_latest_stat(stats)
          stats.max_by { |stat| stat[:date] }
        end

        def sum_stat_values(stats, key)
          stats.sum { |stat| stat[key] || 0 }
        end

        def analytics_params
          params.permit(:start_date, :end_date, :cohort_date, :period, :granularity)
        end
      end
    end
  end
end
