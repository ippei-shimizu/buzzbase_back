module RevenueCat
  module Handlers
    # 全 event handler の共通基底。user lookup と subscription 取得の共通フローを提供する。
    # 各サブクラスは `call` だけ実装し、本処理を `with_resolved_subscription` ブロックで包む。
    class BaseHandler
      def initialize(payload)
        @payload = payload
        @event_recorder = SubscriptionEventRecorder.new(payload)
      end

      def call
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      protected

      attr_reader :payload, :event_recorder

      # 初回購入時は subscription が未保存のことがあるため require_persisted で挙動を切り替える。
      # plan_type / platform を書き換える handler は require_known_product を true にし、
      # 未登録の product_id / store を silent に保存することを防ぐ。
      def with_resolved_subscription(require_persisted: true, require_known_product: false)
        user = UserResolver.resolve(payload.app_user_id)
        return UserResolver.notify_unknown(payload.app_user_id) unless user

        subscription = user.subscription_or_default
        return if require_persisted && !subscription.persisted?
        return if require_known_product && unknown_product?

        yield user, subscription
      end

      private

      # PlanCatalog に未登録の product_id / store が来ると plan_type: nil 等で silent に
      # 保存されてしまうため、書き込み系 handler は事前にガードする。
      def unknown_product?
        plan_type_missing = PlanCatalog.plan_type_from(payload.product_id).nil?
        platform_missing = PlanCatalog.platform_from(payload.store).nil?
        return false unless plan_type_missing || platform_missing

        Sentry.capture_message(
          "RevenueCat: unknown product_id=#{payload.product_id.inspect} or store=#{payload.store.inspect}",
          level: :warning
        )
        true
      end
    end
  end
end
