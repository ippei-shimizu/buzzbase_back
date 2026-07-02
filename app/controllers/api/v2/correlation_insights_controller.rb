module Api
  module V2
    # 相関インサイト。練習量・コンディション × 成績の傾向カードを返す（Pro 限定）。
    class CorrelationInsightsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def show
        unless current_api_v1_user.has_entitlement?('correlation_insights')
          return render json: { error: '相関インサイトは Pro プラン限定です' }, status: :forbidden
        end

        insights = Insights::CorrelationBuilder.new(user: current_api_v1_user).call
        render json: { insights: }, status: :ok
      end
    end
  end
end
