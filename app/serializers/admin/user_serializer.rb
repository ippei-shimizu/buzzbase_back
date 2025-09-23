module Admin
  class UserSerializer < ActiveModel::Serializer
    attributes :id, :name, :email, :user_id, :created_at, :last_login_at,
               :formatted_created_at, :formatted_last_login_at, :activity_status

    def formatted_created_at
      object.created_at.strftime('%Y年%m月%d日')
    end

    def formatted_last_login_at
      return 'ログイン履歴なし' unless object.last_login_at

      object.last_login_at.strftime('%Y年%m月%d日 %H:%M')
    end

    def activity_status
      return 'inactive' unless object.last_login_at

      if object.last_login_at > 1.day.ago
        'active'
      elsif object.last_login_at > 7.days.ago
        'recent'
      else
        'inactive'
      end
    end
  end
end
