class ShadowSwingSession < ApplicationRecord
  belongs_to :user
  belongs_to :practice_log, optional: true

  MENU_NAME = '素振り'.freeze
  UNIT_LABEL = '本'.freeze

  validates :logged_on, presence: true
  validates :target_count, numericality: { greater_than: 0 }
  validates :swing_count, numericality: { greater_than_or_equal_to: 0 }

  # セッションを完了し、素振り由来の練習ログへ本数を記録する。
  # 同じ日に既存の素振りログがあれば加算し、無ければ新規作成する（セット別に
  # 分けず、同日は1レコードへまとめる）。練習ログの after_commit で当日の
  # activity_logs（草・Streak）が再計算される。
  # @param swing_count [Integer] 実際に振った本数
  # @return [self]
  def complete!(swing_count:)
    transaction do
      log = user.practice_logs.find_by(logged_on:, source: 'shadow_swing')
      if log
        log.update!(amount: log.amount.to_i + swing_count)
      else
        log = user.practice_logs.create!(
          practice_menu: nil,
          logged_on:,
          amount: swing_count,
          menu_name: MENU_NAME,
          unit_label: UNIT_LABEL,
          source: 'shadow_swing'
        )
      end
      update!(swing_count:, completed_at: Time.current, practice_log: log)
    end
    self
  end
end
