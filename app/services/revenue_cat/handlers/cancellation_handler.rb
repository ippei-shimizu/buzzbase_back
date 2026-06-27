module RevenueCat
  module Handlers
    # CANCELLATION は解約申請。期限まで Pro 機能利用可なので expires_at は変えない。
    class CancellationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          # Job リトライによる時刻ズレを避けるため、cancelled_at は Webhook payload のイベント時刻を採用する。
          subscription.update!(
            status: 'cancelled',
            cancelled_at: payload.event_timestamp || Time.current,
            last_synced_at: Time.current
          )
          event_recorder.record(user, subscription, 'cancelled')
          SubscriptionCancelledNotificationJob.perform_now(user.id)
        end
      end
    end
  end
end
