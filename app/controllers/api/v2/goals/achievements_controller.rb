module Api
  module V2
    module Goals
      # 定性目標（達成/未達で管理する目標）の達成状態をユーザーが手動で切り替える。
      # 数値目標は指標から自動判定するため対象外。
      class AchievementsController < Api::V2::ApplicationController
        before_action :authenticate_api_v1_user!
        before_action :load_goal

        def create
          return render_not_qualitative unless @goal.qualitative?

          @goal.update!(is_achieved: true, achieved_at: Time.current)
          render json: ::V2::GoalSerializer.new(@goal).as_json, status: :ok
        end

        def destroy
          return render_not_qualitative unless @goal.qualitative?

          @goal.update!(is_achieved: false, achieved_at: nil)
          render json: ::V2::GoalSerializer.new(@goal).as_json, status: :ok
        end

        private

        def load_goal
          @goal = current_api_v1_user.goals.find(params[:goal_id])
        end

        def render_not_qualitative
          render json: { error: '数値目標は自動判定のため手動で達成にできません' }, status: :unprocessable_entity
        end
      end
    end
  end
end
