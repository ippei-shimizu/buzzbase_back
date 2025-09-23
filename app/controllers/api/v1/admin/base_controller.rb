module Api
  module V1
    module Admin
      class BaseController < ActionController::API
        include ActionController::Cookies
        before_action :authenticate_admin_user!

        private

        def authenticate_admin_user!
          return if current_admin_user

          render json: { errors: ['管理者認証が必要です'] }, status: :unauthorized
        end

        def current_admin_user
          return @current_admin_user if defined?(@current_admin_user)

          @current_admin_user = authenticate_from_jwt_header
        end

        def authenticate_from_jwt_header
          # NOTE: APIリクエストのAuthorizationヘッダーからJWTを取得して認証
          auth_header = request.headers['Authorization']
          if auth_header&.start_with?('Bearer ')
            token = auth_header.split[1]
            return InternalJwtService.authenticate_admin_user(token)
          end

          # NOTE: middlewareでセットされたクッキーからJWTを取得して認証
          token = cookies['admin-jwt']
          return nil unless token

          InternalJwtService.authenticate_admin_user(token)
        end
      end
    end
  end
end
