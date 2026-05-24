module App
  module Stripe
    # Stripe Event オブジェクトを薄くラップした値オブジェクト。
    # gem の Stripe::Event 直接アクセスを各所で散らばらせないため、必要な getter をここに集約する。
    class WebhookPayload
      def initialize(stripe_event)
        @event = stripe_event
      end

      def event_id
        @event.id
      end

      def event_type
        @event.type
      end

      # data.object の中身を Hash 風アクセスで返す。
      # Stripe::StripeObject は OpenStruct 的に [:key] / .key の両方に応答する。
      def data_object
        @event.data&.object || {}
      end

      # data.object.metadata を HashWithIndifferentAccess として返す。
      # Stripe 直送（Symbol キー）と DB 経由（JSON → String キー）の両方を統一して扱えるようにする。
      def metadata
        meta = data_object.respond_to?(:metadata) ? data_object.metadata : nil
        (meta.respond_to?(:to_h) ? meta.to_h : {}).with_indifferent_access
      end

      def customer_id
        data_object.respond_to?(:customer) ? data_object.customer : nil
      end

      def subscription_id
        data_object.respond_to?(:subscription) ? data_object.subscription : nil
      end

      # UserSubscriptionEvent#raw_payload や webhook_events.payload に保存する素の Hash を返す。
      def to_h
        @event.to_hash
      end
    end
  end
end
