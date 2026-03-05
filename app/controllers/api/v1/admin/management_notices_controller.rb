module Api
  module V1
    module Admin
      class ManagementNoticesController < Api::V1::Admin::BaseController
        before_action :set_management_notice, only: %i[show update destroy]

        def index
          notices = ManagementNotice.includes(:created_by).order(created_at: :desc)
          notices = notices.where(status: params[:status]) if params[:status].present?

          render json: {
            management_notices: ActiveModelSerializers::SerializableResource.new(
              notices,
              each_serializer: ::Admin::ManagementNoticeSerializer
            )
          }
        end

        def show
          render json: {
            management_notice: ::Admin::ManagementNoticeSerializer.new(@management_notice)
          }
        end

        def create
          notice = ManagementNotice.new(management_notice_params)
          notice.created_by = current_admin_user

          if notice.save
            render json: {
              message: 'お知らせを作成しました',
              management_notice: ::Admin::ManagementNoticeSerializer.new(notice)
            }, status: :created
          else
            render json: { errors: notice.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @management_notice.update(management_notice_params)
            render json: {
              message: 'お知らせを更新しました',
              management_notice: ::Admin::ManagementNoticeSerializer.new(@management_notice)
            }
          else
            render json: { errors: @management_notice.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @management_notice.destroy!
          render json: { message: 'お知らせを削除しました' }
        end

        private

        def set_management_notice
          @management_notice = ManagementNotice.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['お知らせが見つかりません'] }, status: :not_found
        end

        def management_notice_params
          params.require(:management_notice).permit(:title, :body, :status)
        end
      end
    end
  end
end
