module Api
  module V2
    # 単一メニューの推移・自己ベスト・履歴。:id は practice_menu の id。
    # 推移の詳細表示は Pro 限定機能のため、entitlement を要求する。
    class PracticeMenuTrendsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :require_trend_detail_entitlement

      def show
        menu = current_api_v1_user.practice_menus.find(params[:id])
        render json: ::Practices::MenuTrend.new(current_api_v1_user, menu).call, status: :ok
      end

      private

      def require_trend_detail_entitlement
        return if current_api_v1_user.has_entitlement?('practice_menu_trend_detail')

        render json: { error: 'メニュー推移の詳細表示は Pro プラン限定です' }, status: :forbidden
      end
    end
  end
end
