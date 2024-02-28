module Api
  module V1
    class AuthController < ApplicationController

      def create
        user = User.find_or_initialize_by(uid: user_params[:uid], provider: 'google')
        user.update(user_params.merge(
          confirmation_token: SecureRandom.hex(10),
          confirmed_at: Time.now,
          image: user_params[:image]
        ))

        if user.save
          new_auth_header = user.create_new_auth_token
          response.headers.merge!(new_auth_header)

          render json: { 
            status: 'success', 
            data: user.as_json(only: [:uid, :image]),
            auth: {
              uid: user.uid,
              client: new_auth_header['client'],
              'access-token': new_auth_header['access-token'],
              expiry: new_auth_header['expiry'],
              'token-type': new_auth_header['token-type']
            }
          }
        else
          render json: { status: 'error', message: 'ユーザー情報の保存に失敗しました。' }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:uid, :provider, :image)
      end
    end
  end
end
