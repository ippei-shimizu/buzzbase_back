module Practices
  # 素振り（source: shadow_swing）の推移を年別・月別・日別で集計して返す。
  # 素振りログは practice_menu に紐付かないため MenuTrend とは別サービスに分離する。
  class ShadowSwingTrend
    DAY_LIMIT = 60

    def initialize(user)
      @user = user
    end

    # @return [Hash]
    def call
      logs = @user.practice_logs.where(source: 'shadow_swing').order(logged_on: :desc).to_a
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
        id: nil,
        name: ShadowSwingSession::MENU_NAME,
        unit: 'count',
        unit_label: ShadowSwingSession::UNIT_LABEL,
        is_weight_reps: false
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
        total_volume: 0,
        days_count: group.map(&:logged_on).uniq.size
      }
    end
  end
end
