class ManagementNoticeSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :published_at

  def published_at
    object.published_at&.strftime('%Y年%m月%d日')
  end
end
