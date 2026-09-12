module Api
  module V2
    # タイミングマスタ (3種) を display_order 昇順で返却する。
    class TimingsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        timings = Timing.order(:display_order)
        render json: { timings: ActiveModelSerializers::SerializableResource.new(timings, each_serializer: ::V2::TimingSerializer) }
      end
    end
  end
end
