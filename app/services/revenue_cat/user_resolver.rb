module RevenueCat
  # app_user_id から User を解決する責務。
  # mobile/front 側は `Purchases.configure({ appUserID: user.id.to_s })` する前提だが、
  # 初回 INITIAL_PURCHASE 前は subscription.revenuecat_user_id がまだ nil のため User.id でも引き当てる。
  module UserResolver
    # 解決できない app_user_id を受けたときに投げる。WebhookProcessor がこれを rescue して
    # webhook_event を failed にするため、課金は成立したのに entitlement が付与されない状態が
    # processed 扱いのまま埋もれる（自動復旧できなくなる）のを防ぐ。
    UnresolvedUserError = Class.new(StandardError)

    module_function

    def resolve(app_user_id)
      return nil if app_user_id.blank?

      Subscription.find_by(revenuecat_user_id: app_user_id)&.user ||
        User.find_by(id: app_user_id)
    end

    # 解決できなかったときに Sentry へ通知したうえで UnresolvedUserError を投げる。
    def notify_unknown(app_user_id)
      Sentry.capture_message(
        "RevenueCat: user not found for app_user_id=#{app_user_id.inspect}",
        level: :warning
      )
      raise UnresolvedUserError, "app_user_id=#{app_user_id.inspect} is not resolvable"
    end
  end
end
