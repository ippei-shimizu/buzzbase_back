module RevenueCat
  module Handlers
    # RENEWAL は順序逆転に強い実装が必要。古い expires_at のイベントが後から届いても巻き戻さない。
    # billing_issue → active への遷移時は recovered イベントも同時に記録する。
    class RenewalHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          new_expires_at = payload.expiration_at
          next if outdated_event?(subscription.expires_at, new_expires_at)

          was_billing_issue = subscription.billing_issue?
          subscription.update!(status: 'active', expires_at: new_expires_at, last_synced_at: Time.current)
          event_recorder.record(user, subscription, 'renewed')
          if was_billing_issue
            record_recovery(user, subscription)
            RecoveredNotificationJob.perform_now(user.id)
          end
        end
      end

      private

      def outdated_event?(current_expires_at, new_expires_at)
        current_expires_at.present? && new_expires_at.present? && current_expires_at >= new_expires_at
      end

      # 派生イベントは uniqueness 衝突を避けるため、元イベント ID にサフィックスを付ける。
      def record_recovery(user, subscription)
        event_recorder.record(user, subscription, 'recovered', event_id: "#{payload.event_id}-recovered")
      end
    end
  end
end
