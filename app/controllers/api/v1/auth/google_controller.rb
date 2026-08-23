module Api
  module V1
    module Auth
      class GoogleController < ApplicationController
        skip_before_action :authenticate_user!, only: [:create], raise: false

        def create
          raise GoogleAuthService::InvalidToken, 'IDトークンが指定されていません' if params[:id_token].blank?

          google_data = GoogleAuthService.verify(params[:id_token])

          user = resolve_user(google_data)

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
        rescue ::Users::OauthResolver::EmailMissing
          render json: { errors: ['メールアドレスが取得できませんでした'] }, status: :unauthorized
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        end

        private

        def resolve_user(google_data)
          ::Users::OauthResolver.new(
            provider: 'google',
            uid: google_data[:uid],
            email: google_data[:email],
            name: google_data[:name]
          ).call
        end
      end
    end
  end
end
