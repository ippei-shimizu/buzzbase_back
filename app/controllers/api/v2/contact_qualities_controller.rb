module Api
  module V2
    # 打球の質マスタ (5種) を display_order 昇順で返却する。
    class ContactQualitiesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        contact_qualities = ContactQuality.order(:display_order)
        render json: {
          contact_qualities: ActiveModelSerializers::SerializableResource.new(
            contact_qualities, each_serializer: ::V2::ContactQualitySerializer
          )
        }
      end
    end
  end
end
