module RevenueCat
  module Handlers
    # UNCANCELLATION は「自動更新 ON に戻す」操作。cancelled でないときは何もしない（冪等性）。
    # 再解約（CANCELLATION）との到達順序が逆転したときに解約状態を active へ戻さないよう、
    # 適用済みより古いイベントは捨てる。
    class UncancellationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          next if stale_event?(user)
          next unless subscription.cancelled?

          subscription.update!(status: 'active', cancelled_at: nil, last_synced_at: Time.current)
          event_recorder.record(user, subscription, 'uncancelled')
        end
      end
    end
  end
end
