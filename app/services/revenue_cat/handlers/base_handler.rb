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
      # 永続化済みの subscription は with_lock で排他し、webhook 二重配信・同時到達時の
      # lost update（read-modify-write の交錯）を防ぐ。未保存レコードはロック対象が
      # 存在しないためそのまま yield する。
      #
      # ブロックには第3引数として after_unlock 配列を渡す。メール送信・Push 通知のような
      # 外部 I/O は応答時間が読めず、ロックを保持したまま実行すると同一 subscription への
      # 後続 webhook を待たせ、DB コネクションも占有し続けるため、ここに積んでロック解放後
      # （トランザクションのコミット後）に実行する。
      # ブロック内で next した場合は何も積まれないので、スキップ時に通知だけ飛ぶことはない。
      #
      # @yieldparam user [User]
      # @yieldparam subscription [Subscription]
      # @yieldparam after_unlock [Array<Proc>] ロック解放後に実行したい処理の積み先
      def with_resolved_subscription(require_persisted: true, require_known_product: false)
        user = UserResolver.resolve(payload.app_user_id)
        return UserResolver.notify_unknown(payload.app_user_id) unless user

        subscription = user.subscription_or_default
        return if require_persisted && !subscription.persisted?
        return if require_known_product && unknown_product?

        after_unlock = []
        if subscription.persisted?
          subscription.with_lock { yield user, subscription, after_unlock }
        else
          yield user, subscription, after_unlock
        end
        after_unlock.each(&:call)
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
