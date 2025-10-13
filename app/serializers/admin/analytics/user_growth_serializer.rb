module Admin
  module Analytics
    class UserGrowthSerializer
      class << self
        def serialize(stats_data, granularity = 'daily')
          stats_data.map do |stat|
            {
              date: format_date(stat[:date], granularity),
              new_users: stat[:new_users] || 0,
              total_users: stat[:total_users] || 0,
              active_users: stat[:active_users] || 0
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
