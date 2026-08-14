module Api
  module V2
    # 週次 / 月次の振り返りレポートは Pro 限定機能。無料ユーザーには一件も返さない
    # （週次はバッチで生成し続けるが、Pro 加入時に過去分をまとめて見せるための蓄積であり、
    # 加入前の閲覧には使わない）。
    # レポート本体はバッチ（GeneratePeriodicReviewJob）が生成し、ここは閲覧と既読化のみ。
    class PeriodicReviewsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        reviews = current_api_v1_user.periodic_reviews.recent_first
        reviews = reviews.none unless pro?
        render json: reviews, each_serializer: ::V2::PeriodicReviewSerializer, pro: pro?, status: :ok
      end

      def update
        # index と同様、無料ユーザーはレビューへ一切アクセスできない（レスポンス経由の露出防止）。
        reviews = current_api_v1_user.periodic_reviews
        reviews = reviews.none unless pro?
        review = reviews.find(params[:id])
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
