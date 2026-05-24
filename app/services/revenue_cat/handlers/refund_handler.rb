module RevenueCat
  module Handlers
    # REFUND は返金確定。Pro 機能を即時無効化するため expires_at を現在に詰める。
    class RefundHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          now = Time.current
          subscription.update!(status: 'expired', refunded_at: now, expires_at: now, last_synced_at: now)
          event_recorder.record(user, subscription, 'refunded')
        end
      end
    end
  end
end
