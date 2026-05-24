module RevenueCat
  module Handlers
    # UNCANCELLATION は「自動更新 ON に戻す」操作。cancelled でないときは何もしない（冪等性）。
    class UncancellationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          next unless subscription.cancelled?

          subscription.update!(status: 'active', cancelled_at: nil, last_synced_at: Time.current)
          event_recorder.record(user, 'uncancelled')
        end
      end
    end
  end
end
