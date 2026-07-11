module Api
  module V2
    # 単一メニューの推移・自己ベスト・履歴。:id は practice_menu の id。
    class PracticeMenuTrendsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def show
        menu = current_api_v1_user.practice_menus.find(params[:id])
        render json: ::Practices::MenuTrend.new(current_api_v1_user, menu).call, status: :ok
      end
    end
  end
end
