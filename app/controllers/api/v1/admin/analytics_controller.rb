module Api
  module V1
    module Admin
      class AnalyticsController < Api::V1::Admin::BaseController
        def dashboard
          dashboard_data = {
            totalUsers: User.count,
            dailyActiveUsers: 0, # TODO: implement actual daily active users
            newRegistrations: User.where(created_at: Date.current.all_day).count,
            monthlyActiveUsers: 0, # TODO: implement actual monthly active users
            userGrowthData: [],
            activityData: []
          }
          render json: dashboard_data
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

        private

        def analytics_params
          params.permit(:start_date, :end_date, :cohort_date, :period)
        end
      end
    end
  end
end
