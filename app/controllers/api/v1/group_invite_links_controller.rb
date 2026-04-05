module Api
  module V1
    class GroupInviteLinksController < ApplicationController
      before_action :authenticate_api_v1_user!

      # GET /api/v1/invite_links/:code
      def show
        invite_link = GroupInviteLink.active.find_by!(code: params[:code])
        group = invite_link.group
        inviter = invite_link.inviter

        render json: {
          group: {
            id: group.id,
            name: group.name,
            icon: group.icon.url,
            member_count: group.accepted_users.size
          },
          inviter: {
            name: inviter.name,
            image: inviter.image
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: '無効な招待コードです' }, status: :not_found
      end

      # POST /api/v1/invite_links/:code/accept
      def accept
        invite_link = GroupInviteLink.active.find_by!(code: params[:code])
        group = invite_link.group
        user = current_api_v1_user

        if group.group_invitations.exists?(user:, state: 'accepted')
          return render json: { error: '既にこのグループのメンバーです' }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          group.group_invitations.create!(user:, state: 'accepted', sent_at: Time.current)
          create_mutual_follow(user, invite_link.inviter)
          create_notification(invite_link.inviter, user, group)
        end

        PushNotificationService.send_to_user(
          invite_link.inviter,
          title: 'BUZZ BASE',
          body: "#{user.name}さんが招待コードでグループに参加しました"
        )

        render json: { success: true, group_id: group.id }
      rescue ActiveRecord::RecordNotFound
        render json: { error: '無効な招待コードです' }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def create_mutual_follow(user, inviter)
        return if user == inviter

        user.follow(inviter, force_accept: true) unless user.following?(inviter)
        inviter.follow(user, force_accept: true) unless inviter.following?(user)
      end

      def create_notification(inviter, new_member, group)
        notification = Notification.create!(
          actor: new_member,
          event_type: 'group_invitation',
          event_id: group.id
        )
        UserNotification.create!(user_id: inviter.id, notification_id: notification.id)
      end
    end
  end
end
