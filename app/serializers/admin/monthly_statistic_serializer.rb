module Admin
  class MonthlyStatisticSerializer < ActiveModel::Serializer
    attributes :year, :month, :month_start_date, :month_end_date,
               :total_users, :avg_daily_active_users, :peak_daily_active_users,
               :avg_weekly_active_users, :new_users, :total_games, :total_posts,
               :total_batting_records, :total_pitching_records,
               :monthly_retention_rate, :user_growth_rate, :engagement_score,
               :month_label, :created_at

    def month_start_date
      object.month_start_date.strftime('%Y-%m-%d')
    end

    def month_end_date
      object.month_end_date.strftime('%Y-%m-%d')
    end

    def month_label
      "#{object.year}年#{object.month}月"
    end

    def monthly_retention_rate
      "#{object.monthly_retention_rate}%" if object.monthly_retention_rate
    end

    def user_growth_rate
      "#{object.user_growth_rate}%" if object.user_growth_rate
    end

    def engagement_score
      return nil unless object.engagement_score

      {
        score: object.engagement_score,
        level: engagement_level(object.engagement_score),
        description: engagement_description(object.engagement_score)
      }
    end

    private

    def engagement_level(score)
      case score
      when 90..100 then 'excellent'
      when 70..89 then 'good'
      when 50..69 then 'average'
      when 30..49 then 'low'
      else 'very_low'
      end
    end

    def engagement_description(score)
      case score
      when 90..100 then '非常に高いエンゲージメント'
      when 70..89 then '高いエンゲージメント'
      when 50..69 then '中程度のエンゲージメント'
      when 30..49 then '低いエンゲージメント'
      else '非常に低いエンゲージメント'
      end
    end
  end
end
