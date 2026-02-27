module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[index destroy read count]

      def index
        return head :forbidden unless current_api_v1_user.user_id == params[:user_id]

        notifications = current_api_v1_user.notifications.includes(:actor).order(created_at: :desc)
        render json: notifications.select { |n| displayable_notification?(n) }.map { |n| serialize_notification(n) }
      end

      def destroy
        notification = current_api_v1_user.notifications.find_by(id: params[:id])
        if notification
          notification.destroy
          render json: { success: true }, status: :ok
        else
          render json: { error: '削除する通知がありません' }, status: :not_found
        end
      end

      def read
        notification = current_api_v1_user.notifications.find(params[:id])
        notification.update(read_at: Time.current) if notification.read_at.nil?
        render json: { success: true }
      end

      def count
        followed_count = current_api_v1_user.notifications.where(event_type: 'followed', read_at: nil).count
        group_invitation_count = current_api_v1_user.notifications.joins('INNER JOIN group_invitations ON notifications.event_id = group_invitations.group_id')
                                                    .where(notifications: { event_type: 'group_invitation', read_at: nil },
                                                           group_invitations: { user_id: current_api_v1_user.id, state: 'pending' })
                                                    .count
        follow_request_count = current_api_v1_user.notifications
                                                  .joins('INNER JOIN relationships ON notifications.event_id = relationships.id')
                                                  .where(notifications: { event_type: 'follow_request', read_at: nil },
                                                         relationships: { followed_id: current_api_v1_user.id, status: 0 })
                                                  .count

        total_count = followed_count + group_invitation_count + follow_request_count
        render json: { count: total_count }
      end

      private

      def displayable_notification?(notification)
        case notification.event_type
        when 'group_invitation'
          GroupInvitation.find_by(group_id: notification.event_id, user_id: current_api_v1_user.id)&.state == 'pending'
        when 'follow_request'
          Relationship.pending.exists?(id: notification.event_id, followed_id: current_api_v1_user.id)
        else
          %w[followed follow_request_accepted].include?(notification.event_type)
        end
      end

      def serialize_notification(notification)
        hash = {
          id: notification.id,
          actor_user_id: notification.actor.user_id,
          actor_name: notification.actor.name,
          actor_icon: notification.actor.image,
          event_type: notification.event_type,
          event_id: notification.event_id,
          read_at: notification.read_at,
          created_at: notification.created_at
        }

        if notification.event_type == 'group_invitation'
          group = Group.find_by(id: notification.event_id)
          hash[:group_name] = group&.name
          hash[:group_invitation] = 'pending'
        end

        hash[:follow_request_id] = notification.event_id if notification.event_type == 'follow_request'

        hash
      end
    end
  end
end
