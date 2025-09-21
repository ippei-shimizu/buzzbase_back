module Admin
  module Analytics
    class TrendsSerializer
      class << self
        def serialize(daily_stats, content_breakdown)
          {
            user_growth: UserGrowthSerializer.serialize(daily_stats),
            activity_trends: ActivityTrendsSerializer.serialize(daily_stats),
            content_breakdown:,
            summary: build_summary_data(daily_stats)
          }
        end

        private

        def build_summary_data(daily_stats)
          return {} if daily_stats.empty?

          latest = daily_stats.last
          {
            total_users: latest.total_users,
            total_games: daily_stats.sum(&:total_games),
            total_posts: daily_stats.sum(&:total_posts),
            avg_daily_active: daily_stats.map(&:active_users).sum.to_f / daily_stats.length
          }
        end
      end
    end
  end
end
