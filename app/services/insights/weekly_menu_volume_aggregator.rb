module Insights
  # 単一の練習メニューの「量」を週（JST 月〜日）ごとに集計する。
  # 相関の入力側変数として使う。weight_reps 系は amount*weight、他は amount 合計。
  class WeeklyMenuVolumeAggregator
    # @param user [User]
    # @param menu [PracticeMenu]
    # @param since [Date] この日付以降（logged_on）を対象にする
    def initialize(user:, menu:, since:)
      @user = user
      @menu = menu
      @since = since
    end

    # @return [Hash{Date=>Float}] 週開始日 => 量
    def call
      logs = @user.practice_logs.where(practice_menu_id: @menu.id).where(logged_on: @since..)
      logs.group_by { |log| log.logged_on.beginning_of_week }
          .transform_values { |week_logs| volume(week_logs) }
    end

    private

    def volume(logs)
      if @menu.unit == 'weight_reps'
        logs.sum { |log| log.amount.to_f * log.weight.to_f }
      else
        logs.sum { |log| log.amount.to_f }
      end
    end
  end
end
