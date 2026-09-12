module Activities
  # ユーザーの連続活動日数（Streak）を算出する。
  # 当日まだ未活動でも、前日まで連続していれば streak は継続中として数える
  # （その日が終わるまでは途切れ扱いにしない）。
  class StreakCalculator
    JST = 'Asia/Tokyo'.freeze

    def initialize(user)
      @user = user
    end

    # 現在の連続日数
    # @return [Integer]
    def current
      today = Time.find_zone(JST).today
      start = active_dates.include?(today) ? today : today - 1
      streak = 0
      day = start
      while active_dates.include?(day)
        streak += 1
        day -= 1
      end
      streak
    end

    # 最長の連続日数
    # @return [Integer]
    def longest
      sorted = active_dates.to_a.sort
      return 0 if sorted.empty?

      longest = 1
      run = 1
      sorted.each_cons(2) do |prev, current_date|
        run = current_date == prev + 1 ? run + 1 : 1
        longest = [longest, run].max
      end
      longest
    end

    def total_active_days
      active_dates.size
    end

    private

    def active_dates
      @active_dates ||= @user.activity_logs.pluck(:activity_date).to_set
    end
  end
end
