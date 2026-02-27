module Admin
  class UserManagementDetailSerializer < ActiveModel::Serializer
    attributes :id, :name, :email, :user_id, :image_url, :introduction,
               :created_at, :last_login_at, :account_status, :activity_status,
               :suspended_at, :suspended_reason, :deleted_at,
               :game_results_count, :batting_averages_count, :pitching_results_count,
               :baseball_notes_count, :groups_count,
               :followers_count, :following_count, :team_name, :is_private

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

    def batting_averages_count
      object.batting_averages.size
    end

    def pitching_results_count
      object.pitching_results.size
    end

    def baseball_notes_count
      object.baseball_notes.size
    end

    def groups_count
      object.groups.size
    end

    delegate :followers_count, to: :object

    delegate :following_count, to: :object

    def team_name
      return nil unless object.team_id

      Team.find_by(id: object.team_id)&.name
    end
  end
end
