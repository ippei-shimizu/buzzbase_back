module Api
  module V1
    module Auth
      class AppleController < ApplicationController
        skip_before_action :authenticate_user!, only: [:create], raise: false

        def create
          raise AppleAuthService::InvalidToken, 'IDトークンが指定されていません' if params[:identity_token].blank?

          apple_data = AppleAuthService.verify(params[:identity_token], full_name: full_name_params)

          user = find_or_create_user(apple_data)

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
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        end

        private

        def find_or_create_user(apple_data)
          user = User.find_by(provider: 'apple', uid: apple_data[:uid])
          return user if user

          raise AppleAuthService::InvalidToken, 'メールアドレスが取得できませんでした' if apple_data[:email].blank?

          user = User.find_by(email: apple_data[:email])
          if user
            attrs = { provider: 'apple', uid: apple_data[:uid] }
            attrs[:confirmed_at] = Time.current if user.confirmed_at.blank?
            user.update!(attrs)
            return user
          end

          User.create!(
            email: apple_data[:email],
            provider: 'apple',
            uid: apple_data[:uid],
            name: apple_data[:name],
            confirmed_at: Time.current
          )
        end

        def full_name_params
          params.permit(full_name: %i[given_name family_name])[:full_name]
        end
      end
    end
  end
end
