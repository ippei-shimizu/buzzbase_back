module Api
  module V2
    # 球種マスタ (10種) を display_order 昇順で返却する。
    class PitchTypesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        pitch_types = PitchType.order(:display_order)
        render json: { pitch_types: ActiveModelSerializers::SerializableResource.new(pitch_types,
                                                                                     each_serializer: ::V2::PitchTypeSerializer) }
      end
    end
  end
end
