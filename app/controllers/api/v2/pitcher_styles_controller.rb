module Api
  module V2
    # 投手タイプマスタ (4種) を display_order 昇順で返却する。
    class PitcherStylesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        pitcher_styles = PitcherStyle.order(:display_order)
        render json: {
          pitcher_styles: ActiveModelSerializers::SerializableResource.new(
            pitcher_styles, each_serializer: ::V2::PitcherStyleSerializer
          )
        }
      end
    end
  end
end
