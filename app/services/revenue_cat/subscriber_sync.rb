module RevenueCat
  # RevenueCat REST API から取得した現在のsubscriber状態でSubscriptionを上書きする。
  # Webhookの取りこぼし・遅延時に、クライアントの「同期更新」操作から明示的に叩く用途。
  # Webhook Handlerと違い単発の状態確定処理のため、通知Jobの発火は行わない
  # (「今の状態を映すだけ」であり、ユーザーへ再度イベント通知すべきではないため)。
  class SubscriberSync
    ENTITLEMENT_ID = 'pro'.freeze

    def initialize(user)
      @user = user
    end

    # @return [Subscription] 更新後のSubscription
    def call
      subscriber = SubscriberClient.fetch_subscriber(@user.id.to_s)
      entitlement = subscriber.dig('entitlements', ENTITLEMENT_ID)
      subscription = @user.subscription || @user.create_subscription!(status: 'free')

      if entitlement
        apply_entitlement(subscription, subscriber, entitlement)
      else
        apply_no_entitlement(subscription)
      end

      subscription
    end

    private

    def apply_entitlement(subscription, subscriber, entitlement)
      product_id = entitlement['product_identifier']
      subscription_detail = subscriber.dig('subscriptions', product_id) || {}
      store = subscription_detail['store'].to_s.upcase
      return if unknown_product?(product_id, store)

      subscription.update!(attributes_for(subscription, product_id, subscription_detail, entitlement))
    end

    # PlanCatalogに未登録のproduct_id/storeが来た場合、plan_type/platformにnilを
    # 静かに保存してしまうとWebhookのHandler群(unknown_product?で更新自体をスキップする)
    # と挙動が非対称になる。Webhookと同様に更新を丸ごとスキップしSentryへ警告する。
    def unknown_product?(product_id, store)
      plan_type_missing = PlanCatalog.plan_type_from(product_id).nil?
      platform_missing = PlanCatalog.platform_from(store).nil?
      return false unless plan_type_missing || platform_missing

      Sentry.capture_message(
        "RevenueCat sync: unknown product_id=#{product_id.inspect} or store=#{store.inspect}",
        level: :warning
      )
      true
    end

    def attributes_for(subscription, product_id, subscription_detail, entitlement)
      expires_at = parse_time(entitlement['expires_date'])
      effective_expires_at = grace_expires_at(entitlement, subscription_detail) || expires_at
      # RevenueCat REST API (GET /v1/subscribers) は period_type を小文字("trial")で返すが、
      # Webhookペイロードは大文字("TRIAL")のため、大文字小文字を無視して判定する。
      is_trial = subscription_detail['period_type'].to_s.casecmp('TRIAL').zero?

      {
        status: status_for(subscription_detail, effective_expires_at, is_trial),
        plan_type: PlanCatalog.plan_type_from(product_id),
        platform: PlanCatalog.platform_from(subscription_detail['store'].to_s.upcase),
        product_id:,
        started_at: parse_time(entitlement['purchase_date']) || subscription.started_at,
        # Subscription#pro_active? / #in_grace_period? はこのカラムで期限内かを判定するため、
        # グレース期間中はグレース期限を保存する(webhook Handlerと同様、グレース中はPro機能を維持する)。
        expires_at: effective_expires_at,
        cancelled_at: parse_time(subscription_detail['unsubscribe_detected_at']) || subscription.cancelled_at,
        refunded_at: parse_time(subscription_detail['refunded_at']) || subscription.refunded_at,
        billing_issue_at: parse_time(subscription_detail['billing_issues_detected_at']) || subscription.billing_issue_at,
        has_used_trial: subscription.has_used_trial || is_trial,
        revenuecat_user_id: @user.id.to_s,
        revenuecat_entitlement_id: ENTITLEMENT_ID,
        last_synced_at: Time.current
      }
    end

    def grace_expires_at(entitlement, subscription_detail)
      parse_time(entitlement['grace_period_expires_date'] || subscription_detail['grace_period_expires_date'])
    end

    # entitlementが存在しない = 一度も加入していないか、期限切れでRevenueCat側から外れた状態。
    def apply_no_entitlement(subscription)
      new_status = subscription.has_used_trial || subscription.product_id.present? ? 'expired' : 'free'
      subscription.update!(status: new_status, last_synced_at: Time.current)
    end

    def status_for(subscription_detail, effective_expires_at, is_trial)
      return 'expired' if effective_expires_at.present? && effective_expires_at <= Time.current
      return 'billing_issue' if subscription_detail['billing_issues_detected_at'].present?
      return 'cancelled' if subscription_detail['unsubscribe_detected_at'].present?
      return 'trial' if is_trial

      'active'
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
