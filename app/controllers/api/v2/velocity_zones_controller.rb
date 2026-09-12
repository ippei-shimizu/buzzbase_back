module Api
  module V2
    # 投手の球速帯マスタ (5種) を display_order 昇順で返却する。
    class VelocityZonesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        velocity_zones = VelocityZone.order(:display_order)
        render json: {
          velocity_zones: ActiveModelSerializers::SerializableResource.new(
            velocity_zones, each_serializer: ::V2::VelocityZoneSerializer
          )
        }
      end
    end
  end
end
