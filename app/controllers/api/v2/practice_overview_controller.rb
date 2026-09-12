module Api
  module V2
    # 練習全体の積み上げサマリー（KPI）。
    class PracticeOverviewController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def show
        render json: ::Practices::OverallSummary.new(current_api_v1_user).call, status: :ok
      end
    end
  end
end
