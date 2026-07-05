module Api
  module V2
    # メニューセット（再利用できる練習メニューの束）。無料は2つまで（PlanLimits）。
    # セット内メニューは items で一括同期する。
    class MenuSetsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_menu_set, only: %i[show update destroy]

      def index
        menu_sets = current_api_v1_user.menu_sets.ordered
                                       .includes(menu_set_items: :practice_menu)
        render json: menu_sets, each_serializer: ::V2::MenuSetSerializer, status: :ok
      end

      def show
        render json: @menu_set, serializer: ::V2::MenuSetSerializer, status: :ok
      end

      def create
        return render json: { error: 'Pro プランでメニューセットを無制限に登録できます' }, status: :forbidden unless current_api_v1_user.can_create_menu_set?

        menu_set = current_api_v1_user.menu_sets.build(menu_set_params)
        assign_items(menu_set)
        if menu_set.save
          render json: menu_set, serializer: ::V2::MenuSetSerializer, status: :created
        else
          render json: { errors: menu_set.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @menu_set.assign_attributes(menu_set_params)
        assign_items(@menu_set) if params[:menu_set].key?(:items)
        if @menu_set.save
          render json: @menu_set, serializer: ::V2::MenuSetSerializer, status: :ok
        else
          render json: { errors: @menu_set.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @menu_set.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_menu_set
        @menu_set = current_api_v1_user.menu_sets.find(params[:id])
      end

      def menu_set_params
        params.require(:menu_set).permit(:name, :note, :sort_order)
      end

      def assign_items(menu_set)
        items = params.dig(:menu_set, :items) || []
        # 他ユーザーの practice_menu_id を紐付けられないよう、所有メニューに限定する（IDOR 防止）。
        allowed_ids = menu_set.user.practice_menus.where(id: items.pluck(:practice_menu_id)).pluck(:id).to_set
        menu_set.menu_set_items.destroy_all if menu_set.persisted?
        items.each_with_index do |item, index|
          next unless allowed_ids.include?(item[:practice_menu_id].to_i)

          menu_set.menu_set_items.build(
            practice_menu_id: item[:practice_menu_id],
            target_value: item[:target_value],
            sort_order: index
          )
        end
      end
    end
  end
end
