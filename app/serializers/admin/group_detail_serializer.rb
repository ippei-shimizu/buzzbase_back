module Admin
  class GroupDetailSerializer < ActiveModel::Serializer
    attributes :id, :name, :icon_url, :group_users_count, :group_invitations_count, :deletable, :created_at, :members, :invitations

    def icon_url
      object.icon&.url
    end

    def group_users_count
      object.group_users.size
    end

    def group_invitations_count
      object.group_invitations.size
    end

    def deletable
      group_users_count.zero?
    end

    def created_at
      object.created_at.strftime('%Y年%m月%d日 %H:%M')
    end

    def members
      object.group_users.includes(:user).map do |group_user|
        user = group_user.user
        {
          id: user.id,
          name: user.name,
          email: user.email,
          user_id: user.user_id,
          image_url: user.image&.url,
          joined_at: group_user.created_at.strftime('%Y年%m月%d日 %H:%M')
        }
      end
    end

    def invitations
      object.group_invitations.includes(:user).map do |invitation|
        user = invitation.user
        {
          id: invitation.id,
          user_name: user&.name,
          user_email: user&.email,
          state: invitation.state,
          sent_at: invitation.sent_at&.strftime('%Y年%m月%d日 %H:%M'),
          responded_at: invitation.responded_at&.strftime('%Y年%m月%d日 %H:%M')
        }
      end
    end
  end
end
