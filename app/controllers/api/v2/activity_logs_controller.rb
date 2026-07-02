module Api
  module V2
    # 草機能（ヒートマップ）と Streak を返す。
    # 無料は直近30日（grass_recent_30days）、Pro は全期間（grass_full_history）。
    class ActivityLogsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      FREE_WINDOW_DAYS = 30

      # GET /api/v2/activity_logs?from=&to=
      def index
        zone = Time.find_zone('Asia/Tokyo')
        today = zone.today
        from = parse_date(params[:from]) || (today - 364)
        to = parse_date(params[:to]) || today

        # 無料ユーザーは直近30日までにクランプ（サーバー側で強制）。
        from = [from, today - (FREE_WINDOW_DAYS - 1)].max unless current_api_v1_user.has_entitlement?('grass_full_history')

        logs = current_api_v1_user.activity_logs.in_range(from, to).order(:activity_date)
        streak = ::Activities::StreakCalculator.new(current_api_v1_user)

        render json: {
          from:,
          to:,
          current_streak_days: streak.current,
          longest_streak_days: streak.longest,
          total_active_days: streak.total_active_days,
          data: ActiveModelSerializers::SerializableResource.new(logs, each_serializer: ::V2::ActivityLogSerializer)
        }, status: :ok
      end

      # GET /api/v2/activity_logs/streak
      def streak
        calculator = ::Activities::StreakCalculator.new(current_api_v1_user)
        render json: {
          current_streak_days: calculator.current,
          longest_streak_days: calculator.longest,
          total_active_days: calculator.total_active_days
        }, status: :ok
      end

      private

      def parse_date(value)
        return nil if value.blank?

        Date.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
