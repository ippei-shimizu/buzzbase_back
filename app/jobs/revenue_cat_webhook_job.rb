# RevenueCat Webhook の本処理を非同期で実行するジョブ。
# Webhook 受信は即時 200 を返す必要があるため、controller では Job 化のみ行い、
# 実際の Subscription 更新はここで RevenueCatWebhookProcessor 経由で行う。
class RevenueCatWebhookJob < ApplicationJob
  queue_as :default

  # ApplicationJob の rescue_from が Sentry 通知付きで例外を再 raise するため、
  # Solid Queue 側でリトライキューに乗せられる。本ジョブ単独でも指数バックオフで最大 5 回リトライする。
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # webhook_event が DB から消えていても落とさない。Sentry の異常通知だけ済ませて終了する。
  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find_by(id: webhook_event_id)
    unless webhook_event
      Rails.logger.warn("RevenueCatWebhookJob: webhook_event not found (id=#{webhook_event_id})")
      return
    end

    RevenueCatWebhookProcessor.new(webhook_event).process
  end
end
