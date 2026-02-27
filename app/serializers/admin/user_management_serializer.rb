module Admin
  class UserManagementSerializer < ActiveModel::Serializer
    attributes :id, :name, :email, :user_id, :image_url, :created_at, :last_login_at,
               :account_status, :activity_status, :game_results_count, :followers_count,
               :following_count, :is_private

    def image_url
      url = object.image&.url
      return nil if url.nil? || url.include?('user-default-yellow')

      url
    end

    delegate :account_status, to: :object

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

    def game_results_count
      object.game_results.size
    end

    delegate :followers_count, to: :object

    delegate :following_count, to: :object
  end
end
