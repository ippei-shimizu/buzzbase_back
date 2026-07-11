module Api
  module V2
    # 素振りカウンターのセッション。基本機能は無料（shadow_swing_basic）。
    # 開始時に作成し、完了時に練習ログを自動生成する。
    class ShadowSwingSessionsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      # POST /api/v2/shadow_swing_sessions
      def create
        session = current_api_v1_user.shadow_swing_sessions.build(
          target_count: params.require(:shadow_swing_session).permit(:target_count)[:target_count],
          logged_on: Time.find_zone('Asia/Tokyo').today
        )
        if session.save
          render json: session, serializer: ::V2::ShadowSwingSessionSerializer, status: :created
        else
          render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v2/shadow_swing_sessions/:id/complete
      def complete
        session = current_api_v1_user.shadow_swing_sessions.find(params[:id])
        session.complete!(swing_count: complete_params[:swing_count].to_i)
        render json: session, serializer: ::V2::ShadowSwingSessionSerializer, status: :ok
      end

      # GET /api/v2/shadow_swing_sessions/stats
      def stats
        zone = Time.find_zone('Asia/Tokyo')
        today = zone.today
        logs = current_api_v1_user.practice_logs.where(source: 'shadow_swing')

        render json: {
          today_count: logs.where(logged_on: today).sum(:amount).to_i,
          month_count: logs.where(logged_on: today.beginning_of_month..today).sum(:amount).to_i,
          total_count: logs.sum(:amount).to_i
        }, status: :ok
      end

      private

      def complete_params
        params.require(:shadow_swing_session).permit(:swing_count)
      end
    end
  end
end
