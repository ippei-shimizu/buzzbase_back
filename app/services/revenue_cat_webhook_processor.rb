# RevenueCat の Webhook payload を受け取って Subscription を更新するエントリポイント。
# 個別 event_type の handler は #346 で順次実装する。本クラスは冪等性と
# エラーハンドリング・Sentry 通知の責務だけを持ち、未対応イベントは Sentry に
# 警告して processed として記録する（再送ループ防止）。
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

  # event_type ごとの分岐。#346 で各 handler を実装する想定で、現状は未対応扱い。
  def handle_event
    case @event_data['type']
    when 'INITIAL_PURCHASE', 'TRIAL_STARTED',
         'RENEWAL', 'CANCELLATION', 'EXPIRATION',
         'BILLING_ISSUE', 'PRODUCT_CHANGE', 'REFUND',
         'UNCANCELLATION'
      # #346 で個別 handler を実装する。現状はスタブとして無処理で processed 扱いにする。
      nil
    else
      Sentry.capture_message(
        "RevenueCat unknown event_type: #{@event_data['type'].inspect}",
        level: :warning
      )
    end
  end
end
