module Api
  module V2
    # メニュー別の積み上げサマリー（累計・今月・記録日数・最終記録日）。
    class PracticeMenuSummariesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        render json: ::Practices::MenuSummary.new(current_api_v1_user).call, status: :ok
      end
    end
  end
end
