module RevenueCat
  module Handlers
    # 全 event handler の共通基底。user lookup と subscription 取得の共通フローを提供する。
    # 各サブクラスは `call` だけ実装し、本処理を `with_resolved_subscription` ブロックで包む。
    class BaseHandler
      # PlanCatalogに未登録のproduct_id/storeを受けたときに投げる。WebhookProcessorがこれを
      # rescueしてwebhook_eventをfailedにするため、課金・プラン変更は成立したのにentitlement
      # が付与されない状態がprocessed扱いのまま埋もれる（自動復旧できなくなる）のを防ぐ。
      UnknownProductError = Class.new(PermanentWebhookError)

      # stale_event? の比較対象。加入の有効／無効が往復しうるイベントだけを並べる。
      ORDERING_SENSITIVE_EVENT_TYPES = %w[cancelled uncancelled billing_issue renewed recovered expired refunded].freeze

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
        UserResolver.notify_unknown(payload.app_user_id) unless user

        subscription = user.subscription_or_default
        return if require_persisted && !subscription.persisted?

        guard_known_product! if require_known_product

        after_unlock = []
        if subscription.persisted?
          subscription.with_lock { yield user, subscription, after_unlock }
        else
          yield user, subscription, after_unlock
        end
        after_unlock.each(&:call)
      end

      # RevenueCat Webhook の到達順序は保証されない。解約→解約撤回のように短時間で
      # 状態が往復すると、後発イベントを適用した後に先発イベントが遅れて届き、
      # 無条件に上書きする handler は有効な状態を巻き戻してしまう（誤った通知メールも飛ぶ）。
      #
      # RenewalHandler / ExpirationHandler は expires_at という「イベント固有の比較軸」を
      # 持つためそれで判定できるが、CANCELLATION / UNCANCELLATION / BILLING_ISSUE は
      # expires_at を変えないため比較軸がない。そこで監査ログ（UserSubscriptionEvent）の
      # occurred_at 最大値を「適用済みイベント時刻」のマーカーとして使う。
      #
      # マーカーは加入状態の遷移を表すイベントに限る。initial_purchase / trial_started /
      # purchased / product_changed は解約状態と競合せず、これらを含めると
      # 「プラン変更が先に処理され、実際には先行していた解約が遅れて届く」ケースで
      # 正当な解約を stale と誤判定してしまう。
      #
      # 同時刻は再配信の冪等な再適用とみなし stale としない。
      # event_timestamp を持たない payload はマーカーと比較できないため素通しする。
      #
      # @param user [User]
      # @return [Boolean] 適用済みより古いイベントなら true
      def stale_event?(user)
        event_at = payload.event_timestamp
        return false if event_at.blank?

        latest_applied_at = user.user_subscription_events
                                .where(event_type: ORDERING_SENSITIVE_EVENT_TYPES)
                                .maximum(:occurred_at)
        latest_applied_at.present? && event_at < latest_applied_at
      end

      private

      # PlanCatalog に未登録の product_id / store が来ると plan_type: nil 等で silent に
      # 保存されてしまうため、書き込み系 handler は事前にガードする。
      # 名前に `!` を付けているのは、真偽値を返す述語ではなく「未登録なら例外を投げて
      # 止める」副作用を持つことを呼び出し側で分かるようにするため。
      def guard_known_product!
        plan_type_missing = PlanCatalog.plan_type_from(payload.product_id).nil?
        platform_missing = PlanCatalog.platform_from(payload.store).nil?
        return unless plan_type_missing || platform_missing

        Sentry.capture_message(
          "RevenueCat: unknown product_id=#{payload.product_id.inspect} or store=#{payload.store.inspect}",
          level: :warning
        )
        raise UnknownProductError,
              "product_id=#{payload.product_id.inspect} or store=#{payload.store.inspect} is not registered in PlanCatalog"
      end
    end
  end
end
