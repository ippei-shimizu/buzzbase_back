module Admin
  class TeamDetailSerializer < ActiveModel::Serializer
    attributes :id, :name, :category_name, :prefecture_name, :match_results_count, :deletable, :created_at, :members

    def category_name
      object.category&.name
    end

    def prefecture_name
      object.prefecture&.name
    end

    def match_results_count
      @match_results_count ||= MatchResult.where(my_team_id: object.id).or(MatchResult.where(opponent_team_id: object.id)).count
    end

    def deletable
      match_results_count.zero?
    end

    def created_at
      object.created_at.strftime('%Y年%m月%d日 %H:%M')
    end

    def members
      ::User.where(team_id: object.id).map do |user|
        {
          id: user.id,
          name: user.name,
          email: user.email,
          user_id: user.user_id,
          image_url: user.image&.url,
          created_at: user.created_at.strftime('%Y年%m月%d日 %H:%M')
        }
      end
    end
  end
end
