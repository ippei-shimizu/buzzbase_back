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
      def with_resolved_subscription(require_persisted: true)
        user = UserResolver.resolve(payload.app_user_id)
        return UserResolver.notify_unknown(payload.app_user_id) unless user

        subscription = user.subscription_or_default
        return if require_persisted && !subscription.persisted?

        yield user, subscription
      end
    end
  end
end
