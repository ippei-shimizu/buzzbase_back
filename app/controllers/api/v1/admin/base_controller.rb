module Api
  module V1
    module Admin
      class BaseController < ActionController::API
        before_action :authenticate_admin_user!

        private

        def authenticate_admin_user!
          return if current_admin_user

          render json: { errors: ['管理者認証が必要です'] }, status: :unauthorized
        end

        def current_admin_user
          return @current_admin_user if defined?(@current_admin_user)

          @current_admin_user = authenticate_from_session || authenticate_from_jwt
        end

        def authenticate_from_session
          return nil unless session[:admin_user_id]

          ::Admin::User.find_by(id: session[:admin_user_id])
        end

        def authenticate_from_jwt
          auth_header = request.headers['Authorization']
          return nil unless auth_header&.start_with?('Bearer ')

          token = auth_header.split[1]
          InternalJwtService.authenticate_admin_user(token)
        end
      end
    end
  end
end
