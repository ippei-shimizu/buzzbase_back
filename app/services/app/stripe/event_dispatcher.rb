module App
  module Stripe
    # event_type → Handler クラスのマッピング。新 event 対応時はここに 1 行追加するだけ。
    # 未対応 event は UnhandledEventHandler に流して受信記録のみとする。
    module EventDispatcher
      HANDLERS = {
        'checkout.session.completed' => Handlers::CheckoutSessionCompletedHandler
      }.freeze

      module_function

      def handler_for(payload)
        handler_class = HANDLERS.fetch(payload.event_type, Handlers::UnhandledEventHandler)
        handler_class.new(payload)
      end
    end
  end
end
