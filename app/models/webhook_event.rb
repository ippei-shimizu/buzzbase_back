class WebhookEvent < ApplicationRecord
  STATUSES = %w[pending processed failed skipped].freeze

  # enqueue自体が失敗した場合や、enqueue後にjobがロスト（Job基盤の障害等）した場合に
  # 再送で復旧できるよう、この時間を過ぎた enqueued_at は「無かったもの」として
  # 再claimを許可する。
  STALE_ENQUEUE_THRESHOLD = 10.minutes

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

  # job の enqueue 可否を原子的に判定する。
  #
  # 同一イベントの近接同時配信（find_or_create_pending! の RecordNotUnique 敗者側を含む）や
  # enqueue失敗からの再送で、このメソッドが同じレコードに対してほぼ同時に呼ばれることがある。
  # 「pending かつ enqueued_at が無い（or 十分古い）」を条件にした update_all 一発で判定する
  # ことで、複数リクエストが同時に呼んでも成功するのは1回だけになる（DBのUPDATEが唯一の勝者を
  # 決めるため、Ruby側でのロックや排他制御は不要）。
  #
  # @return [Boolean] enqueueしてよいか（true を返したときだけ呼び出し側は perform_later する）
  def claim_for_enqueue!
    # update_all は原子性（1クエリでの条件付きUPDATE）そのものが目的のため、
    # バリデーションをスキップする通常の注意点はここでは当てはまらない。
    # rubocop:disable Rails/SkipsModelValidations
    self.class
        .where(id:, status: 'pending')
        .where('enqueued_at IS NULL OR enqueued_at < ?', STALE_ENQUEUE_THRESHOLD.ago)
        .update_all(enqueued_at: Time.current) == 1
    # rubocop:enable Rails/SkipsModelValidations
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
