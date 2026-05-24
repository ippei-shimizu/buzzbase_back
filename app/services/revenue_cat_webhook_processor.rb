# RevenueCat Webhook payload を Subscription 更新に変換するエントリポイント。
# 未対応イベントも Sentry warning を残しつつ processed として記録し、RevenueCat 側の再送ループを防ぐ。
class RevenueCatWebhookProcessor
  def initialize(webhook_event)
    @webhook_event = webhook_event
    @payload = webhook_event.payload || {}
    @event_data = @payload['event'] || {}
  end

  def process
    return if @webhook_event.processed?

    handle_event
    @webhook_event.mark_processed!
  rescue StandardError => e
    @webhook_event.mark_failed!(e.message)
    Sentry.capture_exception(e, tags: { source: 'revenuecat_webhook' })
    raise
  end

  private

  # 既知イベントは受信記録だけ残して processed 扱いにし、未知イベントは Sentry warning に流す。
  def handle_event
    case @event_data['type']
    when 'INITIAL_PURCHASE', 'TRIAL_STARTED',
         'RENEWAL', 'CANCELLATION', 'EXPIRATION',
         'BILLING_ISSUE', 'PRODUCT_CHANGE', 'REFUND',
         'UNCANCELLATION'
      # TODO: 各 event_type ごとに Subscription を更新する handler を実装する
      #   - INITIAL_PURCHASE / TRIAL_STARTED: subscription を trial / active に遷移、has_used_trial を true
      #   - RENEWAL: expires_at を更新（古いイベントなら無視して順序非依存性を担保）
      #   - CANCELLATION: cancelled_at をセット、expires_at は維持
      #   - EXPIRATION: status を expired に
      #   - BILLING_ISSUE: billing_issue_at をセット、Grace 期間を維持
      #   - PRODUCT_CHANGE: plan_type を切替
      #   - REFUND: status を expired に、expires_at を即時切れに、refunded_at をセット
      #   - UNCANCELLATION: cancelled_at をクリアし active に戻す
      nil
    else
      Sentry.capture_message(
        "RevenueCat unknown event_type: #{@event_data['type'].inspect}",
        level: :warning
      )
    end
  end
end
