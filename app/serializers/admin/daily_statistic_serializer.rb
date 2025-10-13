module Admin
  class DailyStatisticSerializer < ActiveModel::Serializer
    attributes :date, :total_users, :active_users, :new_users,
               :total_games, :total_posts, :total_batting_records,
               :total_pitching_records, :created_at

    def date
      object.date.strftime('%Y-%m-%d')
    end
  end
end
