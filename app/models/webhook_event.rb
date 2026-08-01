class WebhookEvent < ApplicationRecord
  STATUSES = %w[pending processed failed skipped].freeze

  validates :provider, presence: true
  validates :external_event_id, presence: true,
                                uniqueness: { scope: :provider }
  validates :status, inclusion: { in: STATUSES }

  # provider × external_event_id をキーに pending な受信レコードを取得する。
  # 既存レコードがあれば status を書き換えず返す（同一イベント二重受信時の冪等性確保）。
  # 同一イベントが同時到達すると find_or_create_by! は SELECT → INSERT の間で競合し
  # RecordNotUnique になりうるため、rescue して勝者の既存行を返す（500 を防ぐ）。
  #
  # NOTE: 外側のトランザクション内から呼んではならない。RecordNotUnique でトランザクションが
  # abort 状態になり、rescue 節の find_by! も道連れで失敗するため。
  # 現状の呼び出し元（Stripe / RevenueCat の webhook コントローラ）はいずれもトランザクション外。
  # @return [WebhookEvent]
  def self.find_or_create_pending!(provider:, external_event_id:, event_type:, payload:)
    find_or_create_by!(provider:, external_event_id:) do |we|
      we.event_type = event_type
      we.payload = payload
      we.received_at = Time.current
      we.status = 'pending'
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(provider:, external_event_id:)
  end

  STATUSES.each do |status_name|
    define_method("#{status_name}?") { status == status_name }
  end

  # ジョブが処理完了した時点で呼ぶ。受信〜処理完了までの間に Sentry / 監査で参照される。
  def mark_processed!
    update!(status: 'processed', processed_at: Time.current, error_message: nil)
  end

  # ジョブが例外で落ちた時点で呼ぶ。error_message は Sentry 紐付け用の短い説明。
  def mark_failed!(message)
    update!(status: 'failed', error_message: message)
  end
end
