module RevenueCat
  # app_user_id から User を解決する責務。
  # mobile/front 側は `Purchases.configure({ appUserID: user.id.to_s })` する前提だが、
  # 初回 INITIAL_PURCHASE 前は subscription.revenuecat_user_id がまだ nil のため User.id でも引き当てる。
  module UserResolver
    module_function

    def resolve(app_user_id)
      return nil if app_user_id.blank?

      Subscription.find_by(revenuecat_user_id: app_user_id)&.user ||
        User.find_by(id: app_user_id)
    end

    # 解決できなかったときに Sentry へ通知する。webhook 自体は processed として残すため例外は投げない。
    def notify_unknown(app_user_id)
      Sentry.capture_message(
        "RevenueCat: user not found for app_user_id=#{app_user_id.inspect}",
        level: :warning
      )
      nil
    end
  end
end
