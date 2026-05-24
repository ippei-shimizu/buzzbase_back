module RevenueCat
  module Handlers
    # INITIAL_PURCHASE / TRIAL_STARTED 兼用。period_type で trial / active を出し分け、
    # 早期特典期間内のタイムスタンプなら is_early_subscriber を立てる。
    class InitialPurchaseHandler < BaseHandler
      def call
        with_resolved_subscription(require_persisted: false, require_known_product: true) do |user, subscription|
          is_trial = payload.trial?
          started_at = payload.event_timestamp

          subscription.update!(
            status: is_trial ? 'trial' : 'active',
            plan_type: PlanCatalog.plan_type_from(payload.product_id),
            platform: PlanCatalog.platform_from(payload.store),
            product_id: payload.product_id,
            started_at:,
            expires_at: payload.expiration_at,
            has_used_trial: is_trial || subscription.has_used_trial,
            is_early_subscriber: TrialDaysCalculator.in_early_window?(started_at),
            revenuecat_user_id: payload.app_user_id,
            last_synced_at: Time.current
          )
          event_recorder.record(user, subscription, is_trial ? 'trial_started' : 'initial_purchase')
        end
      end
    end
  end
end
