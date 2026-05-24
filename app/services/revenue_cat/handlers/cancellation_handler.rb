module RevenueCat
  module Handlers
    # CANCELLATION は解約申請。期限まで Pro 機能利用可なので expires_at は変えない。
    class CancellationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          subscription.update!(
            status: 'cancelled',
            cancelled_at: Time.current,
            last_synced_at: Time.current
          )
          event_recorder.record(user, 'cancelled')
        end
      end
    end
  end
end
