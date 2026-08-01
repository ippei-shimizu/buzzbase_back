module RevenueCat
  module Handlers
    # EXPIRATION は期限到来時の最終ステータス。Pro 機能を無効化する。
    # RENEWAL 同様に順序逆転への耐性が必要。新しい RENEWAL で expires_at が延長された後に
    # 古い EXPIRATION が遅れて届いても、有効な subscription を expired に落とさない。
    class ExpirationHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription, after_unlock|
          next if outdated_expiration?(subscription.expires_at, payload.expiration_at)

          subscription.update!(status: 'expired', last_synced_at: Time.current)
          event_recorder.record(user, subscription, 'expired')
          after_unlock << -> { SubscriptionExpiredNotificationJob.perform_now(user.id) }
        end
      end

      private

      # 現在の expires_at がイベントの expiration_at より後 = 別イベントで延長済み。
      # 等しい場合は正規の期限到来なので expired へ進める（RenewalHandler の >= とは境界が異なる）。
      def outdated_expiration?(current_expires_at, event_expires_at)
        current_expires_at.present? && event_expires_at.present? && current_expires_at > event_expires_at
      end
    end
  end
end
