module RevenueCat
  module Handlers
    # CANCELLATION は解約申請。期限まで Pro 機能利用可なので expires_at は変えない。
    # 解約撤回（UNCANCELLATION）との到達順序が逆転すると有効な課金を cancelled へ
    # 巻き戻すため、適用済みより古いイベントは捨てる。
    class CancellationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription, after_unlock|
          next if stale_event?(user)

          # Job リトライによる時刻ズレを避けるため、cancelled_at は Webhook payload のイベント時刻を採用する。
          subscription.update!(
            status: 'cancelled',
            cancelled_at: payload.event_timestamp || Time.current,
            last_synced_at: Time.current
          )
          event_recorder.record(user, subscription, 'cancelled')
          after_unlock << -> { SubscriptionCancelledNotificationJob.perform_now(user.id) }
        end
      end
    end
  end
end
