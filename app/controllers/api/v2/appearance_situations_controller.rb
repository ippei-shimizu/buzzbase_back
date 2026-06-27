module Api
  module V2
    # 投手の登板状況マスタ (3種: 先発 / 中継ぎ / 抑え) を display_order 昇順で返却する。
    class AppearanceSituationsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        appearance_situations = AppearanceSituation.order(:display_order)
        render json: {
          appearance_situations: ActiveModelSerializers::SerializableResource.new(
            appearance_situations, each_serializer: ::V2::AppearanceSituationSerializer
          )
        }
      end
    end
  end
end
