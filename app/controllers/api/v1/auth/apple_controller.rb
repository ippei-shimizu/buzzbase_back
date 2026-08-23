module Api
  module V1
    module Auth
      class AppleController < ApplicationController
        skip_before_action :authenticate_user!, only: [:create], raise: false

        def create
          raise AppleAuthService::InvalidToken, 'IDトークンが指定されていません' if params[:identity_token].blank?

          apple_data = AppleAuthService.verify(params[:identity_token], full_name: full_name_params)

          user = resolve_user(apple_data)

          return render json: { errors: ['アカウントが停止されています'] }, status: :unauthorized if user.suspended_at.present?
          return render json: { errors: ['アカウントが削除されています'] }, status: :unauthorized if user.deleted_at.present?

          auth_token = user.create_new_auth_token
          response.headers.merge!(auth_token)

          render json: {
            data: ActiveModelSerializers::SerializableResource.new(user),
            requires_username: user.user_id.blank?
          }, status: :ok
        rescue AppleAuthService::InvalidToken => e
          Rails.logger.error "Apple Auth Error: #{e.message}"
          render json: { errors: [e.message] }, status: :unauthorized
        rescue ::Users::OauthResolver::EmailMissing
          render json: { errors: ['メールアドレスが取得できませんでした'] }, status: :unauthorized
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        end

        private

        def resolve_user(apple_data)
          ::Users::OauthResolver.new(
            provider: 'apple',
            uid: apple_data[:uid],
            email: apple_data[:email],
            name: apple_data[:name]
          ).call
        end

        def full_name_params
          params.permit(full_name: %i[given_name family_name])[:full_name]
        end
      end
    end
  end
end
