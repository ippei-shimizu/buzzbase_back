module RevenueCat
  # UserSubscriptionEvent に監査ログを書き込む責務。
  #
  # 設計方針: ログ記録は subscription 状態更新と独立した「fire-and-forget」とする。
  # 監査ログの整合性 < ビジネス状態の整合性 と位置づけ、ログ記録の失敗が
  # subscription 状態更新を巻き戻さないようにする（トランザクションでくくらない）。
  # 失敗は Sentry へ流して後追いリペアで対処する。
  #
  # 派生イベント（例: recovered）は event_id にサフィックスを付けて
  # revenuecat_event_id の uniqueness 衝突を回避する。
  class SubscriptionEventRecorder
    def initialize(payload)
      @payload = payload
    end

    def record(user, subscription, event_type, event_id: @payload.event_id)
      UserSubscriptionEvent.create!(
        user:,
        subscription:,
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
    rescue StandardError => e
      Sentry.capture_exception(
        e,
        tags: { source: 'subscription_event_recorder' },
        extra: { event_type:, event_id:, user_id: user.id }
      )
      nil
    end
  end
end
