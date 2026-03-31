module Api
  module V1
    class DeviceTokensController < ApplicationController
      before_action :authenticate_api_v1_user!

      def create
        # 別ユーザーに紐づいている同じデバイストークンがあれば削除
        DeviceToken.where(token: device_token_params[:token])
                   .where.not(user: current_api_v1_user)
                   .destroy_all

        token = current_api_v1_user.device_tokens.find_or_initialize_by(
          token: device_token_params[:token]
        )
        token.platform = device_token_params[:platform]
        token.save!
        render json: { status: 'success' }, status: :ok
      end

      def destroy
        token = current_api_v1_user.device_tokens.find_by(
          token: device_token_params[:token]
        )
        token&.destroy
        render json: { status: 'success' }, status: :ok
      end

      private

      def device_token_params
        params.require(:device_token).permit(:token, :platform)
      end
    end
  end
end
