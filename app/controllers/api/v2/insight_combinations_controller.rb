module Api
  module V2
    # 「練習と成績のつながり」のユーザー定義カード（入力 × 成績の組み合わせ）。Pro 限定。
    class InsightCombinationsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def create
        unless current_api_v1_user.has_entitlement?('correlation_insights')
          return render json: { error: '「練習と成績のつながり」は Pro プラン限定です' }, status: :forbidden
        end
        unless current_api_v1_user.can_create_insight_combination?
          return render json: { error: '作成できる組み合わせは上限に達しています' }, status: :unprocessable_entity
        end

        combination = current_api_v1_user.insight_combinations.new(combination_params)
        if combination.save
          render json: { message: '作成しました' }, status: :created
        else
          render json: { errors: combination.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        combination = current_api_v1_user.insight_combinations.find(params[:id])
        combination.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def combination_params
        params.require(:insight_combination).permit(:input_type, :practice_menu_id, :metric)
      end
    end
  end
end
