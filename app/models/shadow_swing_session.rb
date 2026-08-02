class ShadowSwingSession < ApplicationRecord
  belongs_to :user
  belongs_to :practice_log, optional: true

  MENU_NAME = '素振り'.freeze
  UNIT_LABEL = '本'.freeze

  # カウンターのインターバル（秒）。無料プランは FREE_INTERVAL_RANGE の範囲のみ選べる。
  INTERVAL_RANGE = (1.0..20.0)
  FREE_INTERVAL_RANGE = (5.0..10.0)

  validates :logged_on, presence: true
  validates :target_count, numericality: { greater_than: 0 }
  validates :swing_count, numericality: { greater_than_or_equal_to: 0 }
  validates :interval_seconds,
            numericality: { greater_than_or_equal_to: INTERVAL_RANGE.first, less_than_or_equal_to: INTERVAL_RANGE.last }
  # 設定値はクライアント側でもロック表示しているが、直接 API を叩けば回避できるためサーバーでも検証する。
  validate :pro_settings_within_entitlements, on: :create

  # セッションを完了し、素振り由来の練習ログへ本数を記録する。
  # 同じ日に既存の素振りログがあれば加算し、無ければ新規作成する（セット別に
  # 分けず、同日は1レコードへまとめる）。練習ログの after_commit で当日の
  # activity_logs（草・Streak）が再計算される。
  #
  # 0本での完了は「開始してすぐ終了した」ケースで、練習実績ではないため練習ログを作らない。
  # 作ってしまうと amount 0 のログが1件分の活動として草・Streak を water down させる。
  # セッション自体は完了扱いにし、開始したまま残らないようにする。
  # @param swing_count [Integer] 実際に振った本数
  # @return [self]
  def complete!(swing_count:)
    # リトライ等の二重リクエストで swing_count が二重加算されないよう冪等にする。
    return self if completed_at.present?

    transaction do
      log = practice_log_for(swing_count)
      update!(swing_count:, completed_at: Time.current, practice_log: log)
    end
    self
  end

  private

  # @return [PracticeLog, nil] 0本のときは記録すべき実績が無いので nil
  def practice_log_for(swing_count)
    return nil if swing_count <= 0

    log = user.practice_logs.find_by(logged_on:, source: 'shadow_swing')
    if log
      log.update!(amount: log.amount.to_i + swing_count)
      return log
    end

    menu = linked_menu
    user.practice_logs.create!(
      practice_menu: menu,
      logged_on:,
      amount: swing_count,
      menu_name: MENU_NAME,
      unit_label: menu&.unit_label || UNIT_LABEL,
      source: 'shadow_swing'
    )
  end

  def pro_settings_within_entitlements
    return if user.blank?

    if interval_seconds.present? && !FREE_INTERVAL_RANGE.cover?(interval_seconds) &&
       !user.has_entitlement?('shadow_swing_custom_interval')
      errors.add(:interval_seconds,
                 "は無料プランでは#{FREE_INTERVAL_RANGE.first.to_i}〜#{FREE_INTERVAL_RANGE.last.to_i}秒のみ選べます")
    end

    return unless vibration_enabled? && !user.has_entitlement?('shadow_swing_vibration')

    errors.add(:vibration_enabled, 'は Pro プラン限定です')
  end

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
