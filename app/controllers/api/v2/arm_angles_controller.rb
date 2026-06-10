module Api
  module V2
    # 腕の角度マスタ (4種) を display_order 昇順で返却する。
    class ArmAnglesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        arm_angles = ArmAngle.order(:display_order)
        render json: {
          arm_angles: ActiveModelSerializers::SerializableResource.new(
            arm_angles, each_serializer: ::V2::ArmAngleSerializer
          )
        }
      end
    end
  end
end
