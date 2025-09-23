module Admin
  class AdminUserSerializer < ActiveModel::Serializer
    attributes :id, :email, :name, :role, :permissions_list,
               :login_count, :last_login_at, :created_at,
               :formatted_last_login, :role_label, :can_be_modified

    def formatted_last_login
      return 'ログイン履歴なし' unless object.last_login_at

      object.last_login_at.strftime('%Y年%m月%d日 %H:%M')
    end

    def role_label
      case object.role
      when 'super_admin' then 'スーパー管理者'
      when 'admin' then '管理者'
      when 'analyst' then 'アナリスト'
      else '不明'
      end
    end

    def can_be_modified
      current_user = instance_options[:current_user]
      return false unless current_user

      current_user.super_admin? && current_user.id != object.id
    end

    def permissions_list
      object.permissions_list || []
    end

    def created_at
      object.created_at.strftime('%Y年%m月%d日')
    end
  end
end
