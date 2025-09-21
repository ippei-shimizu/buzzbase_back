module Admin
  module Analytics
    class UsersSerializer
      class << self
        def serialize(users)
          users.map do |user|
            {
              id: user.id,
              name: user.name,
              email: user.email,
              user_id: user.user_id,
              created_at: user.created_at.strftime('%Y/%m/%d'),
              last_login_at: user.last_login_at&.strftime('%Y/%m/%d %H:%M'),
              game_count: user.game_results.count,
              team_name: user.team&.name
            }
          end
        end
      end
    end
  end
end
