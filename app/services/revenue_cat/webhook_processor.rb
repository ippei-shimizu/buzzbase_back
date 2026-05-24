module RevenueCat
  # RevenueCat Webhook 処理のエントリポイント。
  # 冪等性ガード・例外時の失敗マーク + Sentry 通知の責務だけ持ち、
  # event_type 別の本処理は EventDispatcher 経由で各 Handler に委譲する。
  class WebhookProcessor
    def initialize(webhook_event)
      @webhook_event = webhook_event
      @payload = WebhookPayload.new(webhook_event.payload)
    end

    # failed のレコードは手動で再 enqueue されたとき再処理する設計のため processed のみガードする。
    def process
      return if @webhook_event.processed?

      EventDispatcher.handler_for(@payload).call
      @webhook_event.mark_processed!
    rescue StandardError => e
      @webhook_event.mark_failed!(e.message)
      Sentry.capture_exception(e, tags: { source: 'revenuecat_webhook' })
      raise
    end
  end
end
