module RevenueCat
  module Handlers
    # 未対応の event_type を受信したときのフォールバック。
    # webhook 自体は processed として記録し、再送ループを防ぐ。
    class UnknownEventHandler < BaseHandler
      def call
        Sentry.capture_message(
          "RevenueCat unknown event_type: #{payload.event_type.inspect}",
          level: :warning
        )
      end
    end
  end
end
