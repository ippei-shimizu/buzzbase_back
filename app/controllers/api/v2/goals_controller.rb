module Api
  module V2
    # 目標設定・達成管理。無料は月次2つまで、シーズン目標は Pro 限定。
    class GoalsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_goal, only: %i[update destroy]

      def index
        goals = current_api_v1_user.goals.active.order(deadline: :asc)
        render json: goals, each_serializer: ::V2::GoalSerializer, status: :ok
      end

      def history
        goals = current_api_v1_user.goals.where(is_finalized: true).order(deadline: :desc)
        render json: goals, each_serializer: ::V2::GoalSerializer, status: :ok
      end

      def create
        goal = current_api_v1_user.goals.build(goal_params)
        return render_limit_error(goal) unless allowed_to_create?(goal)

        if goal.save
          render json: ::V2::GoalSerializer.new(goal).as_json, status: :created
        else
          render json: { errors: goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @goal.update(goal_params)
          render json: ::V2::GoalSerializer.new(@goal).as_json, status: :ok
        else
          render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @goal.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_goal
        @goal = current_api_v1_user.goals.find(params[:id])
      end

      def allowed_to_create?(goal)
        if goal.period_type == 'season'
          current_api_v1_user.can_create_season_goal?
        else
          current_api_v1_user.can_create_monthly_goal?
        end
      end

      def render_limit_error(goal)
        message = goal.period_type == 'season' ? 'シーズン目標は Pro プラン限定です' : 'Pro プランで月次目標を無制限に設定できます'
        render json: { error: message }, status: :forbidden
      end

      def goal_params
        params.require(:goal).permit(:title, :period_type, :season_id, :month_start, :deadline,
                                     :metric_key, :target_value, :comparison_type)
      end
    end
  end
end
