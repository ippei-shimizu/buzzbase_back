module Api
  module V2
    # 練習と成績のつながり。練習量・コンディション × 成績の傾向カードを返す（Pro 限定）。
    class CorrelationInsightsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def show
        unless current_api_v1_user.has_entitlement?('correlation_insights')
          return render json: { error: '「練習と成績のつながり」は Pro プラン限定です' }, status: :forbidden
        end

        combinations = current_api_v1_user.insight_combinations.includes(:practice_menu).ordered
        insights = Insights::CorrelationBuilder.new(user: current_api_v1_user).call(combinations:)
        render json: { insights: }, status: :ok
      end
    end
  end
end
