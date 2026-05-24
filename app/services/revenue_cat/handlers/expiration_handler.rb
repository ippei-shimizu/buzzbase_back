module RevenueCat
  module Handlers
    # EXPIRATION は期限到来時の最終ステータス。Pro 機能を無効化する。
    class ExpirationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          subscription.update!(status: 'expired', last_synced_at: Time.current)
          event_recorder.record(user, 'expired')
        end
      end
    end
  end
end
