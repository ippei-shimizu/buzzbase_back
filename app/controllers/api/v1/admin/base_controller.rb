module Api
  module V1
    module Admin
      class BaseController < ActionController::API
        include ActionController::Cookies
        before_action :authenticate_admin_user!
        before_action :set_admin_sentry_context

        rescue_from StandardError do |exception|
          Sentry.capture_exception(exception) if defined?(Sentry)
          render json: { errors: ['内部サーバーエラーが発生しました'] }, status: :internal_server_error
        end

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
          token = cookies['admin-access-token']
          return nil unless token

          InternalJwtService.authenticate_admin_user(token)
        end

        def set_admin_sentry_context
          return unless defined?(Sentry)

          if current_admin_user
            Sentry.set_user(id: current_admin_user.id, email: current_admin_user.email)
          end
          Sentry.set_extras(
            request_id: request.request_id,
            user_agent: request.user_agent,
            admin_controller: true
          )
        end
      end
    end
  end
end
