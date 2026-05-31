module Api
  module V2
    # 球場マスタの取得と追加。
    # ユーザー追加式（チームAPIと同様）で、create 時に `created_by_user_id` を自動付与する。
    class StadiumsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        stadiums = Stadium.includes(:prefecture)
        stadiums = stadiums.where('name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        stadiums = stadiums.where(prefecture_id: params[:prefecture_id]) if params[:prefecture_id].present?
        stadiums = stadiums.order(:name).page(params[:page]).per(params[:per_page] || 20)

        render json: paginated_response(stadiums, ::V2::StadiumSerializer)
      end

      def create
        stadium = Stadium.new(stadium_params.merge(created_by_user: current_api_v1_user))
        if stadium.save
          render json: stadium, serializer: ::V2::StadiumSerializer, status: :created
        else
          render json: { errors: stadium.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def stadium_params
        params.require(:stadium).permit(:name, :prefecture_id)
      end
    end
  end
end
