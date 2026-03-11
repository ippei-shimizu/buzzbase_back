module Api
  module V1
    class ManagementNoticesController < ApplicationController
      def index
        notices = ManagementNotice.published
        render json: {
          management_notices: ActiveModelSerializers::SerializableResource.new(
            notices,
            each_serializer: ManagementNoticeSerializer
          )
        }
      end

      def show
        notice = ManagementNotice.published.find(params[:id])
        render json: {
          management_notice: ManagementNoticeSerializer.new(notice)
        }
      rescue ActiveRecord::RecordNotFound
        render json: { errors: ['お知らせが見つかりません'] }, status: :not_found
      end
    end
  end
end
