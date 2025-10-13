module Admin
  class DashboardSerializer < ActiveModel::Serializer
    attributes :today_stats, :yesterday_stats, :growth_rates, :recent_actions,
               :weekly_trends, :monthly_summary

    def today_stats
      return nil unless object[:today_stats]

      Admin::DailyStatisticSerializer.new(object[:today_stats]).as_json
    end

    def yesterday_stats
      return nil unless object[:yesterday_stats]

      Admin::DailyStatisticSerializer.new(object[:yesterday_stats]).as_json
    end

    def growth_rates
      object[:growth_rates]
    end

    def recent_actions
      object[:recent_actions]&.map do |action|
        {
          id: action[:id],
          user_name: action[:user_name],
          action_type: action[:action_type],
          action_label: action_label(action[:action_type]),
          occurred_at: action[:occurred_at].strftime('%Y-%m-%d %H:%M'),
          time_ago: time_ago_in_words(action[:occurred_at])
        }
      end
    end

    def weekly_trends
      return [] unless object[:weekly_trends]

      ActiveModelSerializers::SerializableResource.new(
        object[:weekly_trends],
        each_serializer: Admin::WeeklyStatisticSerializer
      ).as_json
    end

    def monthly_summary
      return [] unless object[:monthly_summary]

      ActiveModelSerializers::SerializableResource.new(
        object[:monthly_summary],
        each_serializer: Admin::MonthlyStatisticSerializer
      ).as_json
    end

    private

    def action_label(action_type)
      case action_type
      when 'game_created'
        'ゲーム作成'
      when 'batting_recorded'
        '打撃成績記録'
      when 'pitching_recorded'
        '投手成績記録'
      else
        'その他'
      end
    end

    def time_ago_in_words(time)
      time_diff = Time.current - time

      case time_diff
      when (0..(1.minute))
        'たった今'
      when ((1.minute)..(1.hour))
        "#{(time_diff / 1.minute).to_i}分前"
      when ((1.hour)..(1.day))
        "#{(time_diff / 1.hour).to_i}時間前"
      when ((1.day)..(1.week))
        "#{(time_diff / 1.day).to_i}日前"
      else
        time.strftime('%m月%d日')
      end
    end
  end
end
