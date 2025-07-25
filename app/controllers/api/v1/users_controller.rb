module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[update show_current destroy]
      skip_after_action :update_auth_header, only: [:destroy]
      before_action :set_user, only: %i[show_current_user_id following_users followers_users]

      def show_current
        render json: { id: current_api_v1_user.id }
      end

      def show_current_user_id
        if @user
          render json: { user_id: @user.user_id }
        else
          render json: { error: 'ユーザーが見つかりません。' }, status: :not_found
        end
      end

      def show_by_user_id
        user = User.find_by(user_id: params[:user_id])
        if user
          render json: { id: user.id }
        else
          render json: { error: 'ユーザーが存在しません' }
        end
      end

      def show_user_id_data
        user = User.find_by(user_id: params[:user_id])
        return render json: { error: 'ユーザーが存在しません' }, status: :not_found unless user

        is_following = current_api_v1_user ? current_api_v1_user.following?(user) : false
        if user
          render json: { user: user.as_json, isFollowing: is_following, following_count: user.following_count, followers_count: user.followers_count }
        else
          render json: { error: 'ユーザーが存在しません' }, status: :not_found
        end
      end

      def show_current_user_details
        user = current_api_v1_user
        if user
          render json: { user_id: user.user_id, image: user.image }
        else
          render json: {}, status: :ok
        end
      end

      def show
        render json: current_api_v1_user
      end

      def update
        if current_api_v1_user.update(user_params)
          render json: { success: true }
        else
          render json: { errors: current_api_v1_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def following_users
        @following_users = @user.following.map do |user|
          user_attributes = {
            id: user.id,
            name: user.name,
            user_id: user.user_id,
            image: { url: user.image.url }
          }
          is_following = current_api_v1_user ? current_api_v1_user.following?(user) : false
          user_attributes.merge(isFollowing: is_following)
        end
        render json: @following_users
      end

      def followers_users
        @followers_users = @user.followers.map do |user|
          user_attributes = {
            id: user.id,
            name: user.name,
            user_id: user.user_id,
            image: { url: user.image.url }
          }
          is_following = current_api_v1_user ? current_api_v1_user.following?(user) : false
          user_attributes.merge(isFollowing: is_following)
        end
        render json: @followers_users
      end

      def search
        query = params[:query]
        users = User.where('name LIKE ? OR user_id LIKE ?', "%#{query}%", "%#{query}%")
        render json: users
      end

      def destroy
        current_api_v1_user.destroy!
        render json: { success: true, message: 'アカウントが削除されました' }
      rescue StandardError => e
        Rails.logger.error "Account deletion failed: #{e.message}"
        render json: {
          success: false,
          error: 'アカウントの削除に失敗しました。しばらく時間をおいてから再度お試しください。'
        }, status: :internal_server_error
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :user_id, :introduction, :image, :team_id)
      end
    end
  end
end
