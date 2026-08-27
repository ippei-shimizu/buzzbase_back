module Api
  module V2
    # 球場マスタの取得と追加。
    # ユーザー追加式（チームAPIと同様）で、create 時に `created_by_user_id` を自動付与する。
    class StadiumsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      # 1ページあたりの上限件数。クライアントから大きな値を渡されてもこの値で頭打ちにする。
      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 20

      def index
        stadiums = Stadium.includes(:prefecture)
        stadiums = stadiums.where('name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        stadiums = stadiums.where(prefecture_id: params[:prefecture_id]) if params[:prefecture_id].present?
        stadiums = stadiums.order(:name).page(params[:page]).per(per_page_size)

        render json: paginated_response(stadiums, ::V2::StadiumSerializer)
      end

      # 同名の球場が既にあれば作成せず既存を返す（冪等）。
      # 試合登録で球場名を手入力するたびに同名レコードが増えるのを防ぐ。
      def create
        stadium = Stadium.find_or_initialize_for(
          name: stadium_params[:name],
          prefecture_id: stadium_params[:prefecture_id].presence
        )
        # 既存を返すときは初代作成者を保持する。
        stadium.created_by_user = current_api_v1_user unless stadium.persisted?

        if stadium.persisted? || stadium.save
          render json: stadium, serializer: ::V2::StadiumSerializer, status: :created
        else
          render json: { errors: stadium.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def stadium_params
        params.require(:stadium).permit(:name, :prefecture_id)
      end

      def per_page_size
        requested = params[:per_page].to_i
        return DEFAULT_PER_PAGE if requested <= 0

        [requested, MAX_PER_PAGE].min
      end
    end
  end
end
