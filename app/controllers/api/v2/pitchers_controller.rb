module Api
  module V2
    # 相手投手マスタの取得と追加。
    #
    # 投手は **ユーザー固有マスタ** として扱う（球場マスタとは異なる）:
    # - `GET /api/v2/pitchers` は current_api_v1_user が作成した投手のみ返す
    # - `POST /api/v2/pitchers` は created_by_user を current_api_v1_user に固定
    class PitchersController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 20

      def index
        pitchers = current_api_v1_user.created_pitchers
                                      .includes(:arm_angle, :velocity_zone, :pitcher_style)
        pitchers = pitchers.where('name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        pitchers = pitchers.where(team_id: params[:team_id]) if params[:team_id].present?
        pitchers = pitchers.order(:name).page(params[:page]).per(per_page_size)

        render json: paginated_response(pitchers, ::V2::PitcherSerializer)
      end

      def create
        pitcher = Pitcher.new(pitcher_params.merge(created_by_user: current_api_v1_user))
        if pitcher.save
          render json: pitcher, serializer: ::V2::PitcherSerializer, status: :created
        else
          render json: { errors: pitcher.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def pitcher_params
        params.require(:pitcher).permit(
          :name, :team_id, :throw_hand,
          :arm_angle_id, :velocity_zone_id, :pitcher_style_id
        )
      end

      def per_page_size
        requested = params[:per_page].to_i
        return DEFAULT_PER_PAGE if requested <= 0

        [requested, MAX_PER_PAGE].min
      end
    end
  end
end
