module Practices
  # 単一メニューの推移（直近6ヶ月の月次集計）・自己ベスト・最近の履歴を返す。
  class MenuTrend
    JST = 'Asia/Tokyo'.freeze
    MONTHS = 6

    def initialize(user, menu)
      @user = user
      @menu = menu
    end

    # @return [Hash]
    def call
      logs = @user.practice_logs.where(practice_menu_id: @menu.id).order(logged_on: :desc).to_a
      {
        menu: menu_info,
        monthly: monthly(logs),
        best: {
          max_amount: logs.filter_map(&:amount).max&.to_f,
          max_weight: logs.filter_map(&:weight).max&.to_f
        },
        recent: logs.first(10).map { |log| serialize_log(log) }
      }
    end

    private

    def menu_info
      {
        id: @menu.id,
        name: @menu.name,
        unit: @menu.unit,
        unit_label: @menu.unit_label,
        is_weight_reps: @menu.unit == 'weight_reps'
      }
    end

    def serialize_log(log)
      { id: log.id, logged_on: log.logged_on.to_s, amount: log.amount&.to_f, weight: log.weight&.to_f }
    end

    def monthly(logs)
      start = Time.find_zone(JST).today.beginning_of_month.prev_month(MONTHS - 1)
      grouped = logs.select { |log| log.logged_on >= start }
                    .group_by { |log| log.logged_on.beginning_of_month }
      (0...MONTHS).map do |index|
        month = start.next_month(index)
        bucket(month, grouped[month] || [])
      end
    end

    def bucket(month, group)
      {
        month: month.strftime('%Y-%m'),
        total_amount: group.sum { |log| log.amount.to_f },
        total_volume: group.sum { |log| log.amount.to_f * log.weight.to_f },
        max_weight: group.filter_map(&:weight).max&.to_f,
        days_count: group.map(&:logged_on).uniq.size
      }
    end
  end
end
