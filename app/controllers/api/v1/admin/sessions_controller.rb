module Api
  module V1
    module Admin
      class SessionsController < Api::V1::Admin::BaseController
        skip_before_action :authenticate_admin_user!, only: %i[create validate]

        def create
          admin_user = ::Admin::User.find_by(email: params[:email])

          if admin_user&.authenticate(params[:password])
            jwt_token = InternalJwtService.encode_token(admin_user.id)

            render json: {
              success: true,
              jwt: jwt_token,
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
          cookies.delete(:admin_jwt)
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
      end
    end
  end
end
