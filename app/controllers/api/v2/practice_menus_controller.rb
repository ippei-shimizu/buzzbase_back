module Api
  module V2
    # 練習メニュー マスターの CRUD。
    # 無料プランは archived 以外 5 件まで（PlanLimits#can_create_practice_menu?）。
    class PracticeMenusController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_practice_menu, only: %i[update destroy]

      def index
        menus = current_api_v1_user.practice_menus.active.ordered
        render json: menus, each_serializer: ::V2::PracticeMenuSerializer, status: :ok
      end

      def create
        return render json: { error: 'Pro プランで練習メニューを無制限に登録できます' }, status: :forbidden unless current_api_v1_user.can_create_practice_menu?

        menu = current_api_v1_user.practice_menus.build(practice_menu_params)
        if menu.save
          render json: menu, serializer: ::V2::PracticeMenuSerializer, status: :created
        else
          render json: { errors: menu.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @practice_menu.update(practice_menu_params)
          render json: @practice_menu, serializer: ::V2::PracticeMenuSerializer, status: :ok
        else
          render json: { errors: @practice_menu.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        # 既存ログの menu_name はスナップショット済みのため、論理削除（archived）で履歴を保つ。
        @practice_menu.update!(archived: true)
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_practice_menu
        @practice_menu = current_api_v1_user.practice_menus.find(params[:id])
      end

      def practice_menu_params
        params.require(:practice_menu).permit(:name, :category, :unit, :unit_label, :default_value, :is_favorite, :sort_order)
      end
    end
  end
end
