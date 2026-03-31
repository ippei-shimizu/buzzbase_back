module Api
  module V1
    module Auth
      class AppleController < ApplicationController
        skip_before_action :authenticate_user!, only: [:create], raise: false

        def create
          raise AppleAuthService::InvalidToken, 'IDトークンが指定されていません' if params[:identity_token].blank?

          apple_data = AppleAuthService.verify(params[:identity_token], full_name: params[:full_name])

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
          render json: { errors: [e.message] }, status: :unauthorized
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        end

        private

        def find_or_create_user(apple_data)
          user = User.find_by(provider: 'apple', uid: apple_data[:uid])
          return user if user

          user = User.find_by(email: apple_data[:email])
          if user
            user.update!(provider: 'apple', uid: apple_data[:uid])
            user.update!(confirmed_at: Time.current) if user.confirmed_at.blank?
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
      end
    end
  end
end
