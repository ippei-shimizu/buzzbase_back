module Practices
  # 練習全体の積み上げサマリー（画面トップのKPI用）。
  class OverallSummary
    JST = 'Asia/Tokyo'.freeze

    def initialize(user)
      @user = user
    end

    # @return [Hash]
    def call
      month_start = Time.find_zone(JST).today.beginning_of_month
      logs = @user.practice_logs
      {
        total_practice_days: logs.distinct.count(:logged_on),
        this_month_practice_days: logs.where(logged_on: month_start..).distinct.count(:logged_on),
        total_swing_count: logs.where(source: 'shadow_swing').sum(:amount).to_i,
        total_volume: logs.where.not(weight: nil).sum(Arel.sql('amount * weight')).to_f,
        total_menus: @user.practice_menus.active.count
      }
    end
  end
end
