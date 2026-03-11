module Api
  module V1
    module Auth
      class GoogleController < ApplicationController
        def create
          google_data = GoogleAuthService.verify(params[:id_token])

          user = find_or_create_user(google_data)

          return render json: { errors: ['アカウントが停止されています'] }, status: :unauthorized if user.suspended_at.present?
          return render json: { errors: ['アカウントが削除されています'] }, status: :unauthorized if user.deleted_at.present?

          auth_token = user.create_new_auth_token
          response.headers.merge!(auth_token)

          render json: {
            data: ActiveModelSerializers::SerializableResource.new(user),
            requires_username: user.user_id.blank?
          }, status: :ok
        rescue GoogleAuthService::InvalidToken => e
          render json: { errors: [e.message] }, status: :unauthorized
        end

        private

        def find_or_create_user(google_data)
          user = User.find_by(provider: 'google', uid: google_data[:uid])
          return user if user

          user = User.find_by(email: google_data[:email])
          if user
            user.update!(provider: 'google', uid: google_data[:uid])
            user.update!(confirmed_at: Time.current) if user.confirmed_at.blank?
            return user
          end

          User.create!(
            email: google_data[:email],
            provider: 'google',
            uid: google_data[:uid],
            name: google_data[:name],
            confirmed_at: Time.current
          )
        end
      end
    end
  end
end
