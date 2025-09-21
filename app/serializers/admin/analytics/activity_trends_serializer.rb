module Admin
  module Analytics
    class ActivityTrendsSerializer
      class << self
        def serialize(stats_data, granularity = 'daily')
          stats_data.map do |stat|
            {
              date: format_date(stat.date, granularity),
              games: stat.total_games || 0,
              batting_records: stat.total_batting_records || 0,
              pitching_records: stat.total_pitching_records || 0,
              total_posts: stat.total_posts || 0
            }
          end
        end

        private

        def format_date(date, granularity)
          case granularity
          when 'weekly'
            "#{date.strftime('%m/%d')}週"
          when 'monthly'
            date.strftime('%Y/%m')
          else
            date.strftime('%m/%d')
          end
        end
      end
    end
  end
end
