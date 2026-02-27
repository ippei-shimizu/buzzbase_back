module Api
  module V1
    class RelationshipsController < ApplicationController
      before_action :authenticate_api_v1_user!

      def create
        user = User.find(params[:followed_id])
        relationship = current_api_v1_user.follow(user)
        if relationship
          if user.is_private?
            notification = Notification.create!(
              actor: current_api_v1_user,
              event_type: 'follow_request',
              event_id: relationship.id
            )
            UserNotification.create!(
              user_id: user.id,
              notification_id: notification.id
            )
            render json: { status: 'success', message: 'Follow request sent.', follow_status: 'pending' }, status: :created
          else
            notification = Notification.create!(
              actor: current_api_v1_user,
              event_type: 'followed',
              event_id: current_api_v1_user.id
            )
            UserNotification.create!(
              user_id: user.id,
              notification_id: notification.id
            )
            render json: { status: 'success', message: 'User followed successfully.', follow_status: 'following' }, status: :created
          end
        else
          render json: { status: 'error', message: 'Unable to follow user.' }, status: :unprocessable_entity
        end
      end

      def destroy
        relationship = current_api_v1_user.active_relationships.find_by(followed_id: params[:id])
        if relationship&.destroy
          render json: { status: 'success', message: 'User unfollowed successfully.' }, status: :ok
        else
          render json: { status: 'error', message: 'Unable to unfollow user.' }, status: :unprocessable_entity
        end
      end

      def accept_follow_request
        relationship = current_api_v1_user.pending_follow_requests.find(params[:id])
        relationship.accepted!
        notification = Notification.create!(
          actor: current_api_v1_user,
          event_type: 'follow_request_accepted',
          event_id: current_api_v1_user.id
        )
        UserNotification.create!(
          user_id: relationship.follower_id,
          notification_id: notification.id
        )
        render json: { status: 'success', message: 'Follow request accepted.' }, status: :ok
      end

      def reject_follow_request
        relationship = current_api_v1_user.pending_follow_requests.find(params[:id])
        relationship.destroy
        render json: { status: 'success', message: 'Follow request rejected.' }, status: :ok
      end
    end
  end
end
