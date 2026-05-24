module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/stripe
      # 10 秒以内に 200 を返す必要があるため、受信時は WebhookEvent への記録だけ済ませてジョブに委譲する。
      # 冪等性は webhook_events の (provider, external_event_id) UNIQUE 制約に委ねる。
      class StripeController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false

        def create
          event = verify_and_parse_event
          return head :unauthorized unless event

          webhook_event = WebhookEvent.find_or_create_pending!(
            provider: 'stripe',
            external_event_id: event.id,
            event_type: event.type,
            payload: event.to_hash
          )

          # 既存レコードが返ったときはジョブも enqueue 済みなので新規作成時のみ起動する。
          App::Stripe::WebhookJob.perform_later(webhook_event.id) if webhook_event.previously_new_record?
          head :ok
        rescue StandardError => e
          Sentry.capture_exception(e, tags: { source: 'stripe_webhook_controller' })
          head :internal_server_error
        end

        private

        # ::Stripe::Webhook.construct_event は raw body と Stripe-Signature ヘッダを必要とする。
        # 検証失敗は SignatureVerificationError、JSON 不正は JSON::ParserError を投げる。
        def verify_and_parse_event
          payload = request.body.read
          sig_header = request.headers['Stripe-Signature']
          ::Stripe::Webhook.construct_event(payload, sig_header, ENV.fetch('STRIPE_WEBHOOK_SECRET'))
        rescue ::Stripe::SignatureVerificationError, JSON::ParserError
          nil
        end
      end
    end
  end
end
