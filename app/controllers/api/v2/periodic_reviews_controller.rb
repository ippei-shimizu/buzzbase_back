module Api
  module V2
    # 週次 / 月次の振り返りレポート。基本部は全員、詳細部・月次は Pro 限定。
    # レポート本体はバッチ（GeneratePeriodicReviewJob）が生成し、ここは閲覧と既読化のみ。
    class PeriodicReviewsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        reviews = current_api_v1_user.periodic_reviews.recent_first
        reviews = reviews.weekly unless pro?
        render json: reviews, each_serializer: ::V2::PeriodicReviewSerializer, pro: pro?, status: :ok
      end

      def update
        review = current_api_v1_user.periodic_reviews.find(params[:id])
        review.update!(read: true)
        render json: review, serializer: ::V2::PeriodicReviewSerializer, pro: pro?, status: :ok
      end

      private

      def pro?
        current_api_v1_user.has_entitlement?('advanced_periodic_review')
      end
    end
  end
end
