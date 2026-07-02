module Practices
  # 単一メニューの推移を年別・月別・日別で集計して返す。
  class MenuTrend
    DAY_LIMIT = 60

    def initialize(user, menu)
      @user = user
      @menu = menu
    end

    # @return [Hash]
    def call
      logs = @user.practice_logs.where(practice_menu_id: @menu.id).order(logged_on: :desc).to_a
      {
        menu: menu_info,
        by_year: grouped(logs) { |log| log.logged_on.year.to_s },
        by_month: grouped(logs) { |log| log.logged_on.strftime('%Y-%m') },
        by_day: grouped(logs) { |log| log.logged_on.to_s }.first(DAY_LIMIT)
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

    def grouped(logs, &)
      logs.group_by(&)
          .map { |period, group| bucket(period, group) }
          .sort_by { |entry| entry[:period] }
          .reverse
    end

    def bucket(period, group)
      {
        period:,
        total_amount: group.sum { |log| log.amount.to_f },
        total_volume: group.sum { |log| log.amount.to_f * log.weight.to_f },
        days_count: group.map(&:logged_on).uniq.size
      }
    end
  end
end
