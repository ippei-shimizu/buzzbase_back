module Api
  module V2
    # 目標設定・達成管理。無料は月次2つまで、シーズン目標は Pro 限定。
    class GoalsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_goal, only: %i[update destroy]

      def index
        goals = current_api_v1_user.goals.active.includes(:practice_menu).order(deadline: :asc)
        render json: goals, each_serializer: ::V2::GoalSerializer, status: :ok
      end

      def history
        goals = current_api_v1_user.goals.where(is_finalized: true).includes(:practice_menu).order(deadline: :desc)
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
        # period_type / season_id は作成後に変更不可（Pro 制限の回避を防ぐ）。
        if @goal.update(update_params)
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
        return false if goal.kind == 'manual' && !current_api_v1_user.can_create_manual_metric_goal?

        case goal.period_type
        when 'season' then current_api_v1_user.can_create_season_goal?
        when 'tournament' then current_api_v1_user.can_create_tournament_goal?
        when 'custom' then current_api_v1_user.can_create_custom_period_goal?
        else current_api_v1_user.can_create_monthly_goal?
        end
      end

      def render_limit_error(goal)
        if goal.kind == 'manual' && !current_api_v1_user.can_create_manual_metric_goal?
          return render json: { error: '自由指標の目標は Pro プラン限定です' }, status: :forbidden
        end

        message = case goal.period_type
                  when 'season' then 'シーズン目標は Pro プラン限定です'
                  when 'tournament' then '大会目標は Pro プラン限定です'
                  when 'custom' then 'カスタム期間の目標は Pro プラン限定です'
                  else 'Pro プランで期間目標を無制限に設定できます'
                  end
        render json: { error: message }, status: :forbidden
      end

      def goal_params
        params.require(:goal).permit(:title, :kind, :period_type, :season_id, :tournament_id, :month_start, :deadline,
                                     :metric_key, :target_value, :comparison_type, :practice_menu_id,
                                     :custom_metric_label, :custom_unit, :manual_current_value)
      end

      # 更新では種類（period_type / season_id）を変更させない。
      def update_params
        params.require(:goal).permit(:title, :month_start, :deadline,
                                     :metric_key, :target_value, :comparison_type, :practice_menu_id,
                                     :custom_metric_label, :custom_unit, :manual_current_value)
      end
    end
  end
end
