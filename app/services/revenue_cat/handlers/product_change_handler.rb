module RevenueCat
  module Handlers
    # PRODUCT_CHANGE は月額↔年額のプラン変更。proration / expires_at の調整は Apple/Stripe 側に任せる。
    class ProductChangeHandler < BaseHandler
      def call
        with_resolved_subscription(require_known_product: true) do |user, subscription|
          subscription.update!(
            plan_type: PlanCatalog.plan_type_from(payload.product_id),
            product_id: payload.product_id,
            last_synced_at: Time.current
          )
          event_recorder.record(user, subscription, 'product_changed')
        end
      end
    end
  end
end
