# Webhook 受信時の 10 秒制限を満たすため、本処理は本ジョブに非同期化する。
class RevenueCatWebhookJob < ApplicationJob
  queue_as :default

  # 指数バックオフで最大 5 回リトライ。ApplicationJob の rescue_from で Sentry 通知される。
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # DB から webhook_event が消えていても落とさない（手動削除や DB 競合に備える）。
  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find_by(id: webhook_event_id)
    unless webhook_event
      Rails.logger.warn("RevenueCatWebhookJob: webhook_event not found (id=#{webhook_event_id})")
      return
    end

    RevenueCatWebhookProcessor.new(webhook_event).process
  end
end
