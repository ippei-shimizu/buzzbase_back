module Api
  module V2
    # 打球方向マスタ (13方向) を zone_polygon 込みで返却する。
    # mobile クライアントはタップ座標から方向ID/深さIDを自動判定するためにゾーン定義を使用する。
    # 既存の `stats#hit_directions`（分析API）とは別物。
    class HitDirectionsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        hit_directions = HitDirection.order(:display_order)
        render json: { hit_directions: ActiveModelSerializers::SerializableResource.new(hit_directions,
                                                                                        each_serializer: ::V2::HitDirectionSerializer) }
      end
    end
  end
end
