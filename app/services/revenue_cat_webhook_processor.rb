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
  # 個別 event_type の本処理は後続で積み増す。
  def handle_event
    case @event_data['type']
    when 'INITIAL_PURCHASE', 'TRIAL_STARTED',
         'RENEWAL', 'CANCELLATION', 'EXPIRATION',
         'BILLING_ISSUE', 'PRODUCT_CHANGE', 'REFUND',
         'UNCANCELLATION'
      nil
    else
      Sentry.capture_message(
        "RevenueCat unknown event_type: #{@event_data['type'].inspect}",
        level: :warning
      )
    end
  end
end
