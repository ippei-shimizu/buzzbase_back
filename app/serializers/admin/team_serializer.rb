module Admin
  class TeamSerializer < ActiveModel::Serializer
    attributes :id, :name, :category_name, :prefecture_name, :user_name, :match_results_count, :deletable, :created_at

    def category_name
      object.category&.name
    end

    def prefecture_name
      object.prefecture&.name
    end

    def user_name
      object.user&.name
    end

    def match_results_count
      MatchResult.where(my_team_id: object.id).or(MatchResult.where(opponent_team_id: object.id)).count
    end

    def deletable
      match_results_count.zero?
    end

    def created_at
      object.created_at.strftime('%Y年%m月%d日 %H:%M')
    end
  end
end
