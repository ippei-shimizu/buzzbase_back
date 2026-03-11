module Admin
  class ManagementNoticeSerializer < ActiveModel::Serializer
    attributes :id, :title, :body, :status, :published_at, :created_at, :created_by_name

    def published_at
      object.published_at&.strftime('%Y年%m月%d日 %H:%M')
    end

    def created_at
      object.created_at.strftime('%Y年%m月%d日 %H:%M')
    end

    def created_by_name
      object.created_by.name
    end
  end
end
