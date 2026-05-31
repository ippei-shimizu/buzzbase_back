module Api
  module V2
    # 打球の深さマスタ (3種) を display_order 昇順で返却する。
    class HitDepthsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        hit_depths = HitDepth.order(:display_order)
        render json: { hit_depths: ActiveModelSerializers::SerializableResource.new(hit_depths, each_serializer: ::V2::HitDepthSerializer) }
      end
    end
  end
end
