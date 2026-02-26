module Api
  module V1
    module Admin
      class UsersController < Api::V1::Admin::BaseController
        before_action :set_user, only: %i[show suspend restore soft_delete]

        def index
          result = ::Admin::UserManagementService.new(search_params).call

          render json: {
            users: ActiveModelSerializers::SerializableResource.new(
              result[:users],
              each_serializer: ::Admin::UserManagementSerializer
            ),
            pagination: result[:pagination]
          }
        end

        def show
          render json: {
            user: ::Admin::UserManagementDetailSerializer.new(@user)
          }
        end

        def suspend
          if @user.deleted_at.present?
            render json: { errors: ['削除済みのユーザーは停止できません'] }, status: :unprocessable_entity
            return
          end

          reason = params[:reason]
          @user.suspend!(reason)
          render json: {
            message: 'ユーザーアカウントを停止しました',
            user: ::Admin::UserManagementDetailSerializer.new(@user)
          }
        end

        def restore
          if @user.suspended_at.blank?
            render json: { errors: ['停止中でないユーザーは復帰できません'] }, status: :unprocessable_entity
            return
          end

          @user.restore!
          render json: {
            message: 'ユーザーアカウントを復帰しました',
            user: ::Admin::UserManagementDetailSerializer.new(@user)
          }
        end

        def soft_delete
          if @user.deleted_at.present?
            render json: { errors: ['既に削除済みのユーザーです'] }, status: :unprocessable_entity
            return
          end

          @user.soft_delete!
          render json: {
            message: 'ユーザーアカウントを削除しました',
            user: ::Admin::UserManagementDetailSerializer.new(@user)
          }
        end

        private

        def set_user
          @user = User.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['ユーザーが見つかりません'] }, status: :not_found
        end

        def search_params
          params.permit(:page, :per_page, :search, :sort_by, :sort_order, :status, :date_from, :date_to)
        end
      end
    end
  end
end
