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
    # リトライ等の二重リクエストで swing_count が二重加算されないよう冪等にする。
    return self if completed_at.present?

    transaction do
      log = user.practice_logs.find_by(logged_on:, source: 'shadow_swing')
      if log
        log.update!(amount: log.amount.to_i + swing_count)
      else
        menu = linked_menu
        log = user.practice_logs.create!(
          practice_menu: menu,
          logged_on:,
          amount: swing_count,
          menu_name: MENU_NAME,
          unit_label: menu&.unit_label || UNIT_LABEL,
          source: 'shadow_swing'
        )
      end
      update!(swing_count:, completed_at: Time.current, practice_log: log)
    end
    self
  end

  private

  # 「素振り」という名前の練習メニューが既にあれば紐付け、積み上げ・推移を一本化する。
  # 単位が「回数」以外の既存メニューは統合すると数値の意味が壊れるため紐付けない
  # （その場合は practice_menu: nil のまま、従来通り別集計になる）。
  # 該当メニューが無ければ「回数」単位で新規作成する。
  # @return [PracticeMenu, nil]
  def linked_menu
    existing = user.practice_menus.find_by(name: MENU_NAME)
    return existing if existing&.unit == 'count'
    return nil if existing

    user.practice_menus.create!(name: MENU_NAME, category: 'batting', unit: 'count', unit_label: UNIT_LABEL)
  end
end
