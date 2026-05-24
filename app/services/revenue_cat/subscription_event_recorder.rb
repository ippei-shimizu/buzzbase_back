module RevenueCat
  # UserSubscriptionEvent に監査ログを書き込む責務。
  # 同一 revenuecat_event_id は uniqueness で弾かれるため、握り潰して冪等性を担保する。
  # 派生イベント（例: recovered）は event_id にサフィックスを付けて衝突を回避する。
  class SubscriptionEventRecorder
    def initialize(payload)
      @payload = payload
    end

    def record(user, event_type, event_id: @payload.event_id)
      UserSubscriptionEvent.create!(
        user:,
        subscription: user.subscription,
        event_type:,
        platform: PlanCatalog.platform_from(@payload.store),
        product_id: @payload.product_id,
        period_type: @payload.period_type,
        occurred_at: @payload.event_timestamp || Time.current,
        raw_payload: @payload.to_h,
        revenuecat_event_id: event_id
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
