module Api
  module V1
    module Admin
      class AdminUsersController < Api::V1::Admin::BaseController
        before_action :set_admin_user, only: %i[show update destroy]

        def index
          @admin_users = ::Admin::User.order(:created_at)
          render json: {
            admin_users: ActiveModelSerializers::SerializableResource.new(
              @admin_users,
              each_serializer: ::Admin::AdminUserSerializer,
              current_user: current_admin_user
            )
          }
        end

        def show
          render json: {
            admin_user: ::Admin::AdminUserSerializer.new(
              @admin_user,
              current_user: current_admin_user
            )
          }
        end

        def create
          @admin_user = ::Admin::User.new(admin_user_params)

          if @admin_user.save
            render json: {
              message: '管理者ユーザーを作成しました',
              admin_user: ::Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }, status: :created
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          update_params = admin_user_update_params

          if update_params[:password].present? || update_params[:password_confirmation].present?
            if update_params[:password].blank? || update_params[:password_confirmation].blank?
              render json: { errors: ['パスワードを変更する場合は、パスワードとパスワード確認の両方を入力してください'] }, status: :unprocessable_entity
              return
            end
            if update_params[:password] != update_params[:password_confirmation]
              render json: { errors: ['パスワードとパスワード確認が一致しません'] }, status: :unprocessable_entity
              return
            end
          else
            update_params = update_params.except(:password, :password_confirmation)
          end

          if @admin_user.update(update_params)
            render json: {
              message: '管理者ユーザーを更新しました',
              admin_user: ::Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          if @admin_user.id == current_admin_user.id
            render json: { errors: ['自分自身を削除することはできません'] }, status: :unprocessable_entity
            return
          end

          @admin_user.destroy!
          render json: { message: '管理者ユーザーを削除しました' }
        end

        private

        def set_admin_user
          @admin_user = ::Admin::User.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['管理者ユーザーが見つかりません'] }, status: :not_found
        end

        def admin_user_params
          params.require(:admin_user).permit(:email, :name, :password, :password_confirmation)
        end

        def admin_user_update_params
          params.require(:admin_user).permit(:email, :name, :password, :password_confirmation)
        end
      end
    end
  end
end
