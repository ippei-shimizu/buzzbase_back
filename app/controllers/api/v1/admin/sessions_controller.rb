module Api
  module V1
    module Admin
      class SessionsController < Api::V1::Admin::BaseController
        skip_before_action :authenticate_admin_user!

        def create
          admin_user = ::Admin::User.find_by(email: params[:email])

          if admin_user&.authenticate(params[:password])
            session[:admin_user_id] = admin_user.id

            render json: {
              success: true,
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
          session.delete(:admin_user_id)
          render json: { success: true, message: 'ログアウトしました' }, status: :ok
        end

        def validate
          if session[:admin_user_id]
            admin_user = ::Admin::User.find_by(id: session[:admin_user_id])
            if admin_user
              render json: {
                success: true,
                user: {
                  id: admin_user.id,
                  email: admin_user.email,
                  name: admin_user.name
                }
              }, status: :ok
            else
              session.delete(:admin_user_id)
              render json: { success: false, error: 'ユーザーが見つかりません' }, status: :unauthorized
            end
          else
            render json: { success: false, error: 'ログインしていません' }, status: :unauthorized
          end
        end
      end
    end
  end
end
