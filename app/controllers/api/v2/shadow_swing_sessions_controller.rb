module Api
  module V2
    # 素振りカウンターのセッション。基本機能は無料（shadow_swing_basic）。
    # 開始時に作成し、完了時に練習ログを自動生成する。
    class ShadowSwingSessionsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :require_trend_detail_entitlement, only: :trend

      # POST /api/v2/shadow_swing_sessions
      def create
        session = current_api_v1_user.shadow_swing_sessions.build(
          create_params.merge(logged_on: Time.find_zone('Asia/Tokyo').today)
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

      # GET /api/v2/shadow_swing_sessions/trend
      # 素振りの推移詳細は Pro 限定（メニュー推移詳細と同じ entitlement）。
      def trend
        render json: ::Practices::ShadowSwingTrend.new(current_api_v1_user).call, status: :ok
      end

      private

      def require_trend_detail_entitlement
        return if current_api_v1_user.has_entitlement?('practice_menu_trend_detail')

        render json: { error: 'メニュー推移の詳細表示は Pro プラン限定です' }, status: :forbidden
      end

      # インターバル・バイブ等の Pro 限定設定は ShadowSwingSession のバリデーションで検証する。
      # カウンター画面はここで保存した値を読むため、クライアント側のロック表示を回避しても
      # サーバーが許可した設定でしか実行できない。
      def create_params
        params.require(:shadow_swing_session)
              .permit(:target_count, :interval_seconds, :vibration_enabled, :sound_enabled, :voice_enabled)
      end

      def complete_params
        params.require(:shadow_swing_session).permit(:swing_count)
      end
    end
  end
end
