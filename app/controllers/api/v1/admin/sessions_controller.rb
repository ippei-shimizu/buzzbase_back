module Api
  module V1
    module Admin
      class SessionsController < Api::V1::Admin::BaseController
        skip_before_action :authenticate_admin_user!, only: %i[create validate refresh]

        def create
          admin_user = ::Admin::User.find_by(email: params[:email])

          if admin_user&.authenticate(params[:password])
            access_token = InternalJwtService.encode_access_token(admin_user.id)
            refresh_result = InternalJwtService.create_refresh_token(admin_user.id)

            render json: {
              success: true,
              access_token:,
              refresh_token: refresh_result[:token],
              user: {
                id: admin_user.id,
                email: admin_user.email,
                name: admin_user.name
              }
            }, status: :ok
          else
            render json: {
              success: false,
              error: 'メールアドレスまたはパスワードが間違っています'
            }, status: :unauthorized
          end
        end

        def destroy
          cookies.delete('admin-access-token')
          cookies.delete('admin-refresh-token')
          render json: { success: true, message: 'ログアウトしました' }, status: :ok
        end

        def validate
          if current_admin_user
            render json: {
              success: true,
              user: {
                id: current_admin_user.id,
                email: current_admin_user.email,
                name: current_admin_user.name
              }
            }, status: :ok
          else
            render json: { success: false, error: 'ログインしていません' }, status: :unauthorized
          end
        end

        def refresh
          refresh_token = cookies['admin-refresh-token']

          if refresh_token.blank?
            render json: { success: false, error: 'リフレッシュトークンがありません' }, status: :unauthorized
            return
          end

          admin_user = InternalJwtService.validate_refresh_token(refresh_token)

          if admin_user
            access_token = InternalJwtService.encode_access_token(admin_user.id)

            render json: {
              success: true,
              access_token:,
              user: {
                id: admin_user.id,
                email: admin_user.email,
                name: admin_user.name
              }
            }, status: :ok
          else
            render json: { success: false, error: 'リフレッシュトークンが無効です' }, status: :unauthorized
          end
        end
      end
    end
  end
end
