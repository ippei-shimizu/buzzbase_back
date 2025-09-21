module Admin
  module Analytics
    class DashboardService
      def call
        {
          today_stats:,
          yesterday_stats:,
          growth_rates: calculate_growth_rates,
          recent_actions: build_recent_actions,
          weekly_trends:,
          monthly_summary:
        }
      end

      private

      def today_stats
        @today_stats ||= Admin::DailyStatistic.calculate_for_date(Date.current)
      end

      def yesterday_stats
        @yesterday_stats ||= Admin::DailyStatistic.find_by(date: Date.current - 1.day)
      end

      def calculate_growth_rates
        {
          total_users: Admin::DailyStatistic.growth_rate(:total_users, 7),
          active_users: Admin::DailyStatistic.growth_rate(:active_users, 7),
          new_users: Admin::DailyStatistic.growth_rate(:new_users, 7),
          total_games: Admin::DailyStatistic.growth_rate(:total_games, 7),
          total_batting_records: Admin::DailyStatistic.growth_rate(:total_batting_records, 7),
          total_pitching_records: Admin::DailyStatistic.growth_rate(:total_pitching_records, 7),
          total_posts: Admin::DailyStatistic.growth_rate(:total_posts, 7)
        }
      end

      def build_recent_actions
        actions = []

        recent_games = GameResult.includes(:user)
                                 .where(created_at: 1.day.ago..Time.current)
                                 .order(created_at: :desc)
                                 .limit(5)

        recent_games.each do |game|
          actions << {
            id: game.id,
            user_name: game.user.name,
            action_type: 'game_created',
            occurred_at: game.created_at
          }
        end

        recent_batting = BattingAverage.includes(:user)
                                       .where(created_at: 1.day.ago..Time.current)
                                       .order(created_at: :desc)
                                       .limit(5)

        recent_batting.each do |batting|
          actions << {
            id: batting.id,
            user_name: batting.user.name,
            action_type: 'batting_recorded',
            occurred_at: batting.created_at
          }
        end

        actions.sort_by { |a| a[:occurred_at] }.reverse.first(10)
      end

      def weekly_trends
        Admin::WeeklyStatistic.recent(4)
      end

      def monthly_summary
        Admin::MonthlyStatistic.recent(3)
      end
    end
  end
end
