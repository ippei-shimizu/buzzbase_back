class ShadowSwingSession < ApplicationRecord
  belongs_to :user
  belongs_to :practice_log, optional: true

  MENU_NAME = '素振り'.freeze
  UNIT_LABEL = '本'.freeze

  validates :logged_on, presence: true
  validates :target_count, numericality: { greater_than: 0 }
  validates :swing_count, numericality: { greater_than_or_equal_to: 0 }

  # セッションを完了し、素振り由来の練習ログを自動生成する。
  # 練習ログの after_commit で当日の activity_logs（草・Streak）が再計算される。
  # @param swing_count [Integer] 実際に振った本数
  # @return [self]
  def complete!(swing_count:)
    transaction do
      log = user.practice_logs.create!(
        practice_menu: nil,
        logged_on:,
        amount: swing_count,
        menu_name: MENU_NAME,
        unit_label: UNIT_LABEL,
        source: 'shadow_swing'
      )
      update!(swing_count:, completed_at: Time.current, practice_log: log)
    end
    self
  end
end
