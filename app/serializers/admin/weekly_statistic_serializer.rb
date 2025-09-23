module Admin
  class WeeklyStatisticSerializer < ActiveModel::Serializer
    attributes :week_start_date, :week_end_date, :total_users,
               :avg_daily_active_users, :peak_daily_active_users,
               :new_users, :total_games, :total_posts,
               :total_batting_records, :total_pitching_records,
               :weekly_retention_rate, :user_growth_rate,
               :week_label, :created_at

    def week_start_date
      object.week_start_date.strftime('%Y-%m-%d')
    end

    def week_end_date
      object.week_end_date.strftime('%Y-%m-%d')
    end

    def week_label
      "#{object.week_start_date.strftime('%m/%d')} - #{object.week_end_date.strftime('%m/%d')}"
    end

    def weekly_retention_rate
      "#{object.weekly_retention_rate}%" if object.weekly_retention_rate
    end

    def user_growth_rate
      "#{object.user_growth_rate}%" if object.user_growth_rate
    end
  end
end
