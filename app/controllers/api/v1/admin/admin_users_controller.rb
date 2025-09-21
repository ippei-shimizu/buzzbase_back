module Api
  module V1
    module Admin
      class AdminUsersController < Api::V1::Admin::BaseController
        before_action :set_admin_user, only: %i[show update destroy update_permissions update_role]
        before_action :ensure_super_admin_permissions, except: %i[index show]

        def index
          @admin_users = Admin::User.order(:created_at)
          render json: {
            admin_users: ActiveModelSerializers::SerializableResource.new(
              @admin_users,
              each_serializer: Admin::AdminUserSerializer,
              current_user: current_admin_user
            )
          }
        end

        def show
          render json: {
            admin_user: Admin::AdminUserSerializer.new(
              @admin_user,
              current_user: current_admin_user
            )
          }
        end

        def create
          @admin_user = Admin::User.new(admin_user_params)

          if @admin_user.save
            render json: {
              message: '管理者ユーザーを作成しました',
              admin_user: Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }, status: :created
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @admin_user.update(admin_user_update_params)
            render json: {
              message: '管理者ユーザーを更新しました',
              admin_user: Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update_permissions
          if @admin_user.update(permissions_list: params[:permissions])
            render json: {
              message: '権限を更新しました',
              admin_user: Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update_role
          if @admin_user.update(role: params[:role])
            render json: {
              message: 'ロールを更新しました',
              admin_user: Admin::AdminUserSerializer.new(
                @admin_user,
                current_user: current_admin_user
              )
            }
          else
            render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @admin_user.destroy!
          render json: { message: '管理者ユーザーを削除しました' }
        end

        private

        def set_admin_user
          @admin_user = Admin::User.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['管理者ユーザーが見つかりません'] }, status: :not_found
        end

        def admin_user_params
          params.require(:admin_user).permit(:email, :name, :password, :password_confirmation, :role, permissions: [])
        end

        def admin_user_update_params
          params.require(:admin_user).permit(:email, :name, :role)
        end
      end
    end
  end
end
