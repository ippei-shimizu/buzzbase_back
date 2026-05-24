module App
  module Stripe
    module Handlers
      # 未対応の event_type を受信したときのフォールバック。
      # webhook 自体は processed として記録し、Stripe 側の再送ループを防ぐ。
      # 状態遷移は RevenueCat 経由が主信号のため、Stripe Webhook では受信記録のみとする。
      class UnhandledEventHandler < BaseHandler
        def call
          # 受信記録のみ。Sentry 通知も不要（想定通りの挙動のため）。
          nil
        end
      end
    end
  end
end
