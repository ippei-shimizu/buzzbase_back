module Admin
  class GroupSerializer < ActiveModel::Serializer
    attributes :id, :name, :icon_url, :group_users_count, :group_invitations_count, :deletable, :created_at

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
  end
end
