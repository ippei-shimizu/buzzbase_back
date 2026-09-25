module Api
  module V1
    module Auth
      class AppleController < ApplicationController
        skip_before_action :authenticate_user!, only: [:create], raise: false

        def create
          raise AppleAuthService::InvalidToken, 'IDトークンが指定されていません' if params[:identity_token].blank?

          apple_data = AppleAuthService.verify(params[:identity_token], full_name: full_name_params)

          user = resolve_user(apple_data)

          unavailable_message = user.account_unavailable_message
          return render json: { errors: [unavailable_message] }, status: :unauthorized if unavailable_message

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
          message = 'メールアドレスが取得できませんでした'
          Rails.logger.error "Apple Auth Error: #{message}"
          render json: { errors: [message] }, status: :unauthorized
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
